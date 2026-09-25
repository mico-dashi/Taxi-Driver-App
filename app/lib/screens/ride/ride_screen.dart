import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../chat/chat_screen.dart';
import 'trip_complete_screen.dart';

/// Live tracking for the passenger, from "driver on the way" to arrival.
class RideScreen extends StatefulWidget {
  const RideScreen({super.key, required this.initial});

  final Ride initial;

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _map = MapController();
  bool _mapReady = false;
  late Ride _ride = widget.initial;
  StreamSubscription<Ride>? _sub;
  List<LatLng> _approach = [];
  bool _follow = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadApproach();
    _sub = context.read<AppState>().backend.watchRide(_ride.id).listen(_onRide);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadApproach() async {
    final route = await context.read<AppState>().routing.route(
      _ride.driver.location,
      _ride.request.pickup.point,
    );
    if (mounted) setState(() => _approach = route.points);
  }

  void _onRide(Ride ride) {
    if (!mounted || _finished) return;
    final prev = _ride.status;
    setState(() => _ride = ride);
    if (_follow && _mapReady) _fitCamera();
    if (prev != ride.status && ride.status == RideStatus.driverArrived) {
      HapticFeedback.heavyImpact();
    }
    if (ride.status == RideStatus.completed) {
      _finished = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TripCompleteScreen(ride: ride)),
      );
    } else if (ride.status == RideStatus.cancelled) {
      _finished = true;
      _showCancelled(ride);
    }
  }

  Future<void> _showCancelled(Ride ride) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('ride_cancelled')),
        content: Text(ctx.tr('ride_cancelled_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('ok')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _fitCamera() {
    final target = _ride.status == RideStatus.inProgress
        ? _ride.request.destination.point
        : _ride.request.pickup.point;
    fitPoints(_map, [
      _ride.driver.location,
      target,
    ], padding: const EdgeInsets.fromLTRB(60, 140, 60, 380));
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: _ride.driver.phone);
    if (_ride.driver.phone.isEmpty || !await launchUrl(uri)) {
      if (mounted) showInfo(context, context.tr('cannot_call'));
    }
  }

  void _message() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          rideId: _ride.id,
          peerName: _ride.driver.name,
          peerPhone: _ride.driver.phone,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.tr('cancel_why'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final r in const [
                'reason_too_far',
                'reason_changed_mind',
                'reason_driver_asked',
                'reason_other_ride',
                'reason_other',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr(r)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      _finished = true;
      await context.read<AppState>().backend.cancelRide(_ride.id, reason);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _finished = false;
      if (mounted) showError(context, e);
    }
  }

  void _share() {
    final r = _ride;
    final text = context.tr('share_text', {
      'driver': r.driver.name,
      'car': '${r.driver.vehicle.title} ${r.driver.vehicle.plate}',
      'to': r.request.destination.name,
      'eta': minutes(r.etaMinutes),
    });
    Clipboard.setData(ClipboardData(text: text));
    showInfo(context, context.tr('copied_share'));
  }

  void _sos() => showSafetySheet(context);

  @override
  Widget build(BuildContext context) {
    final r = _ride;
    final inTrip = r.status == RideStatus.inProgress;
    final arrived = r.status == RideStatus.driverArrived;
    final line = inTrip ? r.request.route.points : _approach;

    final String status;
    final String trailing;
    if (arrived) {
      status = context.tr('driver_arrived');
      trailing = context.tr('now');
    } else if (inTrip) {
      status = context.tr('on_trip');
      trailing = minutes(r.etaMinutes);
    } else {
      status = context.tr('driver_on_way');
      trailing = minutes(r.etaMinutes);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerDown: (_) => _follow = false,
                  child: AppMap(
                    controller: _map,
                    center: r.request.pickup.point,
                    zoom: 15,
                    onReady: () {
                      _mapReady = true;
                      _fitCamera();
                    },
                    children: [
                      if (line.length > 1)
                        PolylineLayer(polylines: [routeLine(line)]),
                      MarkerLayer(
                        markers: [
                          pinMarker(r.request.pickup.point, pickup: true),
                          if (inTrip)
                            pinMarker(
                              r.request.destination.point,
                              pickup: false,
                              label: r.request.destination.name,
                            ),
                          carMarker(r.driver),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.shield_outlined,
                        onTap: _sos,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatusPill(
                          text: status,
                          trailing: trailing,
                          color: arrived
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleIconButton(
                        icon: Icons.my_location_rounded,
                        onTap: () {
                          _follow = true;
                          _fitCamera();
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
                child: SheetCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    arrived
                                        ? 'driver_here'
                                        : inTrip
                                        ? 'heading_to'
                                        : 'arriving_soon',
                                    {'place': r.request.destination.name},
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr(
                                    arrived
                                        ? 'meet_at_pickup'
                                        : inTrip
                                        ? 'enjoy_ride'
                                        : 'heading_to_you',
                                    {'name': r.driver.firstName},
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _EtaBadge(minutes: r.etaMinutes, arrived: arrived),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ProgressTrack(progress: r.progress),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Avatar(r.driver.name, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VerifiedName(
                                  r.driver.name,
                                  verified: r.driver.verified,
                                ),
                                Row(
                                  children: [
                                    Rating(r.driver.rating),
                                    Flexible(
                                      child: Text(
                                        ' · ${r.driver.vehicle.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CarBadge(
                            categoryId: r.driver.vehicle.categoryId,
                            size: 40,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Plate(r.driver.vehicle.plate),
                          const SizedBox(width: 8),
                          Text(
                            r.driver.vehicle.color,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            paymentTypeLabel(context, r.request.payment),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            money(r.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.call_outlined,
                              label: context.tr('call'),
                              onTap: _call,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: context.tr('message'),
                              onTap: _message,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: inTrip
                                ? _ActionButton(
                                    icon: Icons.ios_share_rounded,
                                    label: context.tr('share'),
                                    onTap: _share,
                                  )
                                : _ActionButton(
                                    icon: Icons.cancel_outlined,
                                    label: context.tr('cancel'),
                                    onTap: _cancel,
                                    danger: true,
                                  ),
                          ),
                        ],
                      ),
                    ],
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

class _EtaBadge extends StatelessWidget {
  const _EtaBadge({required this.minutes, required this.arrived});

  final int minutes;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: arrived ? AppColors.success : AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: arrived
          ? const Icon(Icons.check_circle_outline_rounded, color: Colors.white)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${minutes < 1 ? 1 : minutes}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const Text('min', style: TextStyle(fontSize: 10)),
              ],
            ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final x = (c.maxWidth - 20) * progress.clamp(0.0, 1.0);
        return SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                width: x + 10,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 900),
                left: x,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_taxi_rounded, size: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: danger ? AppColors.dangerSoft : AppColors.background,
        foregroundColor: danger ? AppColors.danger : AppColors.ink,
        side: BorderSide.none,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Emergency numbers for Albania.
Future<void> showSafetySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        Widget tile(IconData icon, String label, String number, Color color) =>
            ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(number),
              trailing: const Icon(Icons.call_rounded),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ctx.tr('safety'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                tile(
                  Icons.sos_rounded,
                  ctx.tr('emergency'),
                  AppConfig.emergencyNumber,
                  AppColors.danger,
                ),
                tile(
                  Icons.local_police_outlined,
                  ctx.tr('police'),
                  AppConfig.policeNumber,
                  AppColors.verified,
                ),
                tile(
                  Icons.local_hospital_outlined,
                  ctx.tr('ambulance'),
                  AppConfig.ambulanceNumber,
                  AppColors.success,
                ),
                tile(
                  Icons.support_agent_rounded,
                  ctx.tr('support'),
                  AppConfig.supportPhone,
                  AppColors.ink,
                ),
              ],
            ),
          ),
        );
      },
    );
