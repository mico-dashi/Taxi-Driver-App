import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../services/routing_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../chat/chat_screen.dart';

/// The driver's main screen: go online, get requests, make offers, drive.
class DriveTab extends StatefulWidget {
  const DriveTab({super.key});

  @override
  State<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<DriveTab>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final _mover = MapMover(_map, this);
  DateTime _lastFit = DateTime(2000);
  RideStatus? _fittedFor;
  bool _mapReady = false;
  bool _online = false;
  bool _toggling = false;
  LatLng _me = const LatLng(0, 0);
  List<RideRequest> _requests = [];
  final _skipped = <String>{};

  /// Requests we made an offer on: id -> price.
  final _offered = <String, int>{};
  Ride? _ride;
  List<LatLng> _approach = [];

  StreamSubscription<List<RideRequest>>? _reqSub;
  StreamSubscription<Ride?>? _rideSub;
  StreamSubscription<LatLng>? _gpsSub;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _me = app.here;
    _rideSub = app.backend.watchDriverActiveRide().listen(_onRide);
  }

  @override
  void dispose() {
    _reqSub?.cancel();
    _rideSub?.cancel();
    _gpsSub?.cancel();
    _heartbeat?.cancel();
    _mover.dispose();
    super.dispose();
  }

  Future<void> _onRide(Ride? ride) async {
    if (!mounted) return;
    final wasNew = _ride == null && ride != null;
    setState(() => _ride = ride);
    if (wasNew) {
      HapticFeedback.heavyImpact();
      _offered.clear();
      final route = await context.read<AppState>().routing.route(
        ride.driver.location,
        ride.request.pickup.point,
      );
      if (mounted) setState(() => _approach = route.points);
    }
    if (ride != null && _mapReady && mounted) {
      // In demo mode the simulated car is "our" position.
      if (context.read<AppState>().backend.isDemo) _me = ride.driver.location;
      final target = ride.status == RideStatus.inProgress
          ? ride.request.destination.point
          : ride.request.pickup.point;
      // Re-frame smoothly when the stage changes or every few seconds.
      if (_fittedFor != ride.status ||
          DateTime.now().difference(_lastFit) > const Duration(seconds: 4)) {
        _fittedFor = ride.status;
        _lastFit = DateTime.now();
        _mover.fit([
          _me,
          target,
        ], padding: const EdgeInsets.fromLTRB(60, 140, 60, 360));
      }
    }
  }

  /// This driver's own car, for the map while waiting for requests.
  Driver _meAsDriver() => Driver(
    id: context.read<AppState>().backend.currentUserId,
    name: '',
    phone: '',
    rating: 5,
    trips: 0,
    vehicle: const Vehicle(
      make: '',
      model: '',
      plate: '',
      color: '',
      categoryId: 'standard',
    ),
    location: _me,
  );

  Future<void> _toggleOnline() async {
    final app = context.read<AppState>();
    setState(() => _toggling = true);
    try {
      if (!_online) {
        _me = await app.location.current();
        await app.backend.setOnline(true, _me);
        _reqSub = app.backend.watchIncomingRequests(_me).listen(_onRequests);
        _gpsSub = app.location.watch().listen((p) {
          final heading = RoutingService.bearing(_me, p);
          _me = p;
          app.backend.pushLocation(p, heading);
          if (mounted) setState(() {});
        }, onError: (_) {});
        // Keep "last seen" fresh even when parked.
        _heartbeat = Timer.periodic(
          const Duration(seconds: 30),
          (_) => app.backend.pushLocation(_me, 0),
        );
        if (_mapReady) _mover.animateTo(_me, 15);
      } else {
        await app.backend.setOnline(false, _me);
        await _reqSub?.cancel();
        await _gpsSub?.cancel();
        _heartbeat?.cancel();
        _requests = [];
        _offered.clear();
      }
      setState(() => _online = !_online);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _onRequests(List<RideRequest> list) {
    if (!mounted) return;
    final ids = list.map((r) => r.id).toSet();
    final lost = _offered.keys.where((id) => !ids.contains(id)).toList();
    if (lost.isNotEmpty && _ride == null) {
      showInfo(context, context.tr('passenger_chose_other'));
    }
    for (final id in lost) {
      _offered.remove(id);
    }
    if (list.length > _requests.length) HapticFeedback.mediumImpact();
    setState(() => _requests = list);
  }

  Future<void> _offer(RideRequest r, int price) async {
    setState(() => _offered[r.id] = price);
    try {
      await context.read<AppState>().backend.sendOffer(
        r,
        price,
        RoutingService.etaMinutes(_me, r.pickup.point),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _offered.remove(r.id));
      showError(context, e);
    }
  }

  Future<void> _advance() async {
    final ride = _ride;
    if (ride == null) return;
    final next = switch (ride.status) {
      RideStatus.driverOnTheWay => RideStatus.driverArrived,
      RideStatus.driverArrived => RideStatus.inProgress,
      RideStatus.inProgress => RideStatus.completed,
      _ => null,
    };
    if (next == null) return;
    try {
      await context.read<AppState>().backend.updateRideStatus(ride.id, next);
      if (next == RideStatus.completed && mounted) {
        setState(() => _ride = null);
        await _showCompleted(ride);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _showCompleted(Ride ride) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
        size: 48,
      ),
      title: Text(ctx.tr('trip_completed')),
      content: Text(
        ride.request.payment == PaymentType.cash
            ? ctx.tr('collect_cash', {'amount': money(ride.price)})
            : ctx.tr('paid_by_card', {'amount': money(ride.price)}),
        textAlign: TextAlign.center,
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.tr('ok')),
        ),
      ],
    ),
  );

  Future<void> _cancelRide() async {
    final ride = _ride;
    if (ride == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('cancel_ride_q')),
        content: Text(ctx.tr('cancel_ride_driver_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('yes_cancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().backend.updateRideStatus(
        ride.id,
        RideStatus.cancelled,
      );
      if (mounted) setState(() => _ride = null);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Opens Google Maps (or Waze) with turn-by-turn directions.
  Future<void> _navigate(LatLng to) async {
    final waze = Uri.parse(
      'waze://?ll=${to.latitude},${to.longitude}&navigate=yes',
    );
    final google = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}&travelmode=driving',
    );
    final choice = await showModalBottomSheet<Uri>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Google Maps'),
              onTap: () => Navigator.pop(ctx, google),
            ),
            ListTile(
              leading: const Icon(Icons.navigation_outlined),
              title: const Text('Waze'),
              onTap: () => Navigator.pop(ctx, waze),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!await launchUrl(choice, mode: LaunchMode.externalApplication)) {
      await launchUrl(google, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final visible = _requests.where((r) => !_skipped.contains(r.id)).toList();
    final meDriver = ride?.driver;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: _me,
              zoom: 15,
              onReady: () => _mapReady = true,
              children: [
                if (ride != null)
                  PolylineLayer(
                    polylines: [
                      routeLine(
                        remainingRoute(
                          ride.status == RideStatus.inProgress
                              ? ride.request.route.points
                              : _approach,
                          ride.driver.location,
                        ),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (ride == null)
                      for (final r in visible)
                        pinMarker(r.pickup.point, pickup: true),
                    if (ride != null) ...[
                      pinMarker(ride.request.pickup.point, pickup: true),
                      pinMarker(ride.request.destination.point, pickup: false),
                    ],
                    if (meDriver == null && !_online)
                      Marker(
                        point: _me,
                        width: 30,
                        height: 54,
                        child: const TaxiTopView(dimmed: true),
                      ),
                  ],
                ),
                if (meDriver != null || _online)
                  SmoothCars(
                    drivers: [meDriver ?? _meAsDriver()],
                    duration: Duration(
                      milliseconds: context.read<AppState>().backend.isDemo
                          ? 300
                          : 1500,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: StatusPill(
                      text: ride != null
                          ? context.tr(switch (ride.status) {
                              RideStatus.driverOnTheWay => 'go_to_pickup',
                              RideStatus.driverArrived => 'waiting_passenger',
                              _ => 'drive_to_destination',
                            })
                          : context.tr(
                              _online ? 'you_are_online' : 'you_are_offline',
                            ),
                      color: _online || ride != null
                          ? AppColors.success
                          : AppColors.inkFaint,
                      trailing: ride == null && _online
                          ? context.tr('n_requests', {'n': '${visible.length}'})
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleIconButton(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      if (_mapReady) _mover.animateTo(_me, 15);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ride != null
                ? _ActiveRidePanel(
                    ride: ride,
                    onAdvance: _advance,
                    onNavigate: () => _navigate(
                      ride.status == RideStatus.inProgress
                          ? ride.request.destination.point
                          : ride.request.pickup.point,
                    ),
                    onCancel: _cancelRide,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_online)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final r in visible)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RequestCard(
                                    request: r,
                                    me: _me,
                                    offeredPrice: _offered[r.id],
                                    onOffer: (p) => _offer(r, p),
                                    onSkip: () =>
                                        setState(() => _skipped.add(r.id)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      SheetCard(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr(
                                      _online
                                          ? 'waiting_requests'
                                          : 'go_online_title',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    context.tr(
                                      _online
                                          ? 'waiting_requests_desc'
                                          : 'go_online_desc',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _toggling ? null : _toggleOnline,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(120, 52),
                                backgroundColor: _online
                                    ? AppColors.ink
                                    : AppColors.primary,
                                foregroundColor: _online
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                              child: _toggling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      context.tr(
                                        _online ? 'go_offline' : 'go_online',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.me,
    required this.offeredPrice,
    required this.onOffer,
    required this.onSkip,
  });

  final RideRequest request;
  final LatLng me;
  final int? offeredPrice;
  final ValueChanged<int> onOffer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final pickupEta = RoutingService.etaMinutes(me, r.pickup.point);
    return Material(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(r.passengerName, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.passengerName.isEmpty
                            ? context.tr('passenger')
                            : r.passengerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Rating(r.passengerRating),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(r.offeredFare),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      paymentTypeLabel(context, r.payment),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            RouteSummary(
              pickup: r.pickup.name,
              destination: r.destination.name,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('request_meta', {
                'eta': minutes(pickupEta),
                'km': km(r.route.distanceKm),
                'min': minutes(r.route.durationMin),
              }),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            if (offeredPrice != null)
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('offer_sent_waiting', {
                        'price': money(offeredPrice!),
                      }),
                    ),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  for (final step in Pricing.counterSteps.skip(1))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () => onOffer(r.offeredFare + step),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text('+${money(step)}'),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: onSkip,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.tr('skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => onOffer(r.offeredFare),
                child: Text(
                  context.tr('accept_for', {'price': money(r.offeredFare)}),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveRidePanel extends StatelessWidget {
  const _ActiveRidePanel({
    required this.ride,
    required this.onAdvance,
    required this.onNavigate,
    required this.onCancel,
  });

  final Ride ride;
  final VoidCallback onAdvance;
  final VoidCallback onNavigate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final r = ride.request;
    final (String action, Color color) = switch (ride.status) {
      RideStatus.driverOnTheWay => (context.tr('i_arrived'), AppColors.primary),
      RideStatus.driverArrived => (context.tr('start_trip'), AppColors.success),
      _ => (context.tr('complete_trip'), AppColors.ink),
    };
    final canCancel =
        ride.status == RideStatus.driverOnTheWay ||
        ride.status == RideStatus.driverArrived;
    return SheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(r.passengerName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.passengerName.isEmpty
                          ? context.tr('passenger')
                          : r.passengerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Rating(r.passengerRating),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(ride.price),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    paymentTypeLabel(context, r.payment),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          RouteSummary(pickup: r.pickup.name, destination: r.destination.name),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text(context.tr('navigate')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SquareButton(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatScreen(rideId: ride.id, peerName: r.passengerName),
                  ),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 8),
                _SquareButton(
                  icon: Icons.close_rounded,
                  onTap: onCancel,
                  danger: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onAdvance,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: color == AppColors.primary
                  ? AppColors.ink
                  : Colors.white,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(46, 46),
          padding: EdgeInsets.zero,
          backgroundColor: danger ? AppColors.dangerSoft : null,
          foregroundColor: danger ? AppColors.danger : AppColors.ink,
          side: danger ? BorderSide.none : null,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
