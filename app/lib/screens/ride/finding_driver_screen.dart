import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../services/routing_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import 'ride_screen.dart';

/// Broadcasts the request, shows the radar and handles driver offers.
class FindingDriverScreen extends StatefulWidget {
  const FindingDriverScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.route,
    required this.categoryId,
    required this.fare,
    required this.payment,
  });

  final Place pickup;
  final Place destination;
  final RouteInfo route;
  final String categoryId;
  final int fare;
  final PaymentMethod payment;

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen> {
  final _map = MapController();
  RideRequest? _request;
  List<RideOffer> _offers = [];
  List<Driver> _drivers = [];
  final _declined = <String>{};
  String? _lastDeclinedName;
  Ride? _confirmed;
  bool _accepting = false;
  StreamSubscription<List<RideOffer>>? _offersSub;
  StreamSubscription<List<Driver>>? _driversSub;
  Timer? _ticker;
  Timer? _giveUp;

  static const _searchTimeout = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    final backend = context.read<AppState>().backend;
    _driversSub = backend.watchNearbyDrivers(widget.pickup.point).listen((d) {
      if (mounted) {
        setState(
          () => _drivers = d
              .where((x) => x.vehicle.categoryId == widget.categoryId)
              .toList(),
        );
      }
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    _start();
  }

  Future<void> _start() async {
    final backend = context.read<AppState>().backend;
    try {
      final req = await backend.createRequest(
        pickup: widget.pickup,
        destination: widget.destination,
        route: widget.route,
        categoryId: widget.categoryId,
        offeredFare: widget.fare,
        payment: widget.payment.type,
      );
      if (!mounted) {
        backend.cancelRequest(req.id);
        return;
      }
      setState(() => _request = req);
      _offersSub = backend.watchOffers(req.id).listen((o) {
        if (mounted) setState(() => _offers = o);
      });
      _giveUp = Timer(_searchTimeout, _noDrivers);
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    _driversSub?.cancel();
    _ticker?.cancel();
    _giveUp?.cancel();
    super.dispose();
  }

  /// Offers still inside their countdown, oldest first.
  List<RideOffer> get _liveOffers {
    final now = DateTime.now();
    return _offers
        .where(
          (o) =>
              !_declined.contains(o.id) &&
              now.difference(o.createdAt).inMilliseconds <
                  AppConfig.offerTimeoutSeconds * 1000,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _cancel() async {
    final req = _request;
    if (req != null) {
      await context.read<AppState>().backend.cancelRequest(req.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _noDrivers() async {
    final req = _request;
    if (req == null || _confirmed != null) return;
    await context.read<AppState>().backend.cancelRequest(req.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('no_drivers_title')),
        content: Text(ctx.tr('no_drivers_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('ok')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _decline(RideOffer offer) {
    setState(() {
      _declined.add(offer.id);
      _lastDeclinedName = offer.driver.firstName;
    });
    context.read<AppState>().backend.declineOffer(offer);
  }

  Future<void> _accept(RideOffer offer) async {
    setState(() => _accepting = true);
    try {
      final ride = await context.read<AppState>().backend.acceptOffer(offer);
      _giveUp?.cancel();
      if (!mounted) return;
      setState(() => _confirmed = ride);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => RideScreen(initial: ride)),
      );
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      setState(() {
        _accepting = false;
        _declined.add(offer.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = _liveOffers;
    final offer = offers.isEmpty ? null : offers.first;
    final offerDriverIds = offers.map((o) => o.driver.id).toSet();

    final String status;
    Color statusColor = AppColors.primary;
    if (_confirmed != null) {
      status = context.tr('ride_confirmed');
      statusColor = AppColors.success;
    } else if (offer != null) {
      status = context.tr('offer_from', {'name': offer.driver.firstName});
    } else if (_lastDeclinedName != null) {
      status = context.tr('looking_another');
    } else if (_drivers.isNotEmpty && _request != null) {
      status = context.tr('n_drivers_found', {'n': '${_drivers.length}'});
    } else {
      status = context.tr('searching_nearby');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _confirmed == null) _cancel();
      },
      child: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: AppMap(
                  controller: _map,
                  center: widget.pickup.point,
                  zoom: 14,
                  children: [
                    if (_confirmed == null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.pickup.point,
                            width: 280,
                            height: 280,
                            child: const RadarSweep(size: 280),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [pinMarker(widget.pickup.point, pickup: true)],
                    ),
                    SmoothCars(
                      drivers: _drivers,
                      labelFor: (d) => minutes(
                        RoutingService.etaMinutes(
                          d.location,
                          widget.pickup.point,
                        ),
                      ),
                      highlight: offerDriverIds,
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: _confirmed == null ? _cancel : () {},
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatusPill(text: status, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _confirmed != null
                      ? _ConfirmedCard(
                          key: const ValueKey('confirmed'),
                          ride: _confirmed!,
                        )
                      : offer != null
                      ? _OfferCard(
                          key: ValueKey(offer.id),
                          offer: offer,
                          yourFare: widget.fare,
                          more: offers.length - 1,
                          busy: _accepting,
                          onDecline: () => _decline(offer),
                          onAccept: () => _accept(offer),
                        )
                      : _SearchingCard(
                          key: const ValueKey('searching'),
                          categoryId: widget.categoryId,
                          fare: widget.fare,
                          payment: widget.payment,
                          drivers: _drivers,
                          declinedName: _lastDeclinedName,
                          onCancel: _cancel,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchingCard extends StatelessWidget {
  const _SearchingCard({
    super.key,
    required this.categoryId,
    required this.fare,
    required this.payment,
    required this.drivers,
    required this.declinedName,
    required this.onCancel,
  });

  final String categoryId;
  final int fare;
  final PaymentMethod payment;
  final List<Driver> drivers;
  final String? declinedName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final category = context.tr(Pricing.byId(categoryId).nameKey);
    return SheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('finding_driver'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('asking_drivers', {'category': category}),
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          if (declinedName != null) ...[
            const SizedBox(height: 10),
            Pill(
              context.tr('you_declined', {'name': declinedName!}),
              color: AppColors.dangerSoft,
              textColor: AppColors.danger,
            ),
          ],
          const SizedBox(height: 14),
          CardBox(
            color: AppColors.background,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CarBadge(categoryId: categoryId, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        paymentLabel(context, payment),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('your_fare'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    Text(
                      money(fare),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: drivers.isEmpty
                    ? 24
                    : 24 + 16.0 * (drivers.take(3).length - 1),
                height: 24,
                child: drivers.isEmpty
                    ? const Icon(
                        Icons.radar_rounded,
                        size: 20,
                        color: AppColors.inkSoft,
                      )
                    : Stack(
                        children: [
                          for (var i = 0; i < drivers.take(3).length; i++)
                            Positioned(
                              left: i * 16.0,
                              child: Avatar(drivers[i].name, size: 24),
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  drivers.isEmpty
                      ? context.tr('scanning_streets')
                      : context.tr('n_drivers_waiting', {
                          'n': '${drivers.length}',
                        }),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.background,
              side: BorderSide.none,
            ),
            child: Text(context.tr('cancel_search')),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    super.key,
    required this.offer,
    required this.yourFare,
    required this.more,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final RideOffer offer;
  final int yourFare;
  final int more;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    const total = AppConfig.offerTimeoutSeconds * 1000;
    final left =
        (total - DateTime.now().difference(offer.createdAt).inMilliseconds)
            .clamp(0, total);
    final diff = offer.price - yourFare;
    final d = offer.driver;
    return SheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: left / total,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(left / 1000).ceil()}s',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Avatar(d.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      context.tr('new_offer'),
                      color: AppColors.primarySoft,
                      textColor: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 4),
                    VerifiedName(d.name, verified: d.verified),
                    Rating(d.rating, trips: d.trips),
                  ],
                ),
              ),
              if (more > 0)
                Pill(context.tr('n_more_offers', {'n': '$more'}), dot: false),
            ],
          ),
          const SizedBox(height: 12),
          CardBox(
            color: AppColors.background,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CarBadge(categoryId: d.vehicle.categoryId, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.vehicle.make.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: AppColors.inkFaint,
                        ),
                      ),
                      Text(
                        d.vehicle.model,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${d.vehicle.plate} · ${context.tr('min_away', {'m': minutes(offer.etaMinutes)})}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('your_fare'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  Text(
                    money(yourFare),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.inkFaint,
                      decoration: diff != 0 ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.inkFaint,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('driver_asks', {'name': d.firstName}),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  Text(
                    money(offer.price),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (diff > 0)
                Pill(
                  '+${money(diff)}',
                  color: AppColors.dangerSoft,
                  textColor: AppColors.danger,
                  dot: false,
                )
              else
                Pill(context.tr('your_price'), dot: false),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.dangerSoft,
                    foregroundColor: AppColors.danger,
                    side: BorderSide.none,
                  ),
                  child: Text(context.tr('decline')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text('${context.tr('accept')} ${money(offer.price)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  const _ConfirmedCard({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final d = ride.driver;
    return SheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('ride_confirmed'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('driver_on_way_in', {
              'name': d.firstName,
              'car': d.vehicle.model,
            }),
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          CardBox(
            color: AppColors.background,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Avatar(d.name, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${d.vehicle.plate} · ${context.tr('min_away', {'m': minutes(ride.etaMinutes)})}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(ride.price),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            color: AppColors.success,
            backgroundColor: AppColors.successSoft,
          ),
        ],
      ),
    );
  }
}
