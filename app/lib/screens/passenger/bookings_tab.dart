import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../ride/ride_screen.dart';

/// Ride history + any ride currently in progress.
class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  late Future<(Ride?, List<Ride>)> _data = _load();

  Future<(Ride?, List<Ride>)> _load() async {
    final backend = context.read<AppState>().backend;
    final results = await Future.wait([
      backend.activeRide(),
      backend.rideHistory(),
    ]);
    return (results[0] as Ride?, results[1] as List<Ride>);
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<(Ride?, List<Ride>)>(
          future: _data,
          builder: (context, snap) {
            final active = snap.data?.$1;
            final history = snap.data?.$2 ?? const <Ride>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  context.tr('tab_bookings'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (active != null) ...[
                  SectionLabel(context.tr('active_ride')),
                  _RideTile(
                    ride: active,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RideScreen(initial: active),
                      ),
                    ),
                  ),
                ],
                if (snap.hasData) ...[
                  SectionLabel(context.tr('past_rides')),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          context.tr('no_rides'),
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    ),
                  for (final r in history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RideTile(
                        ride: r,
                        onTap: () => _showReceipt(context, r),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, Ride r) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.tr('receipt'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${dayMonth(r.createdAt)} · ${hhmm(r.createdAt)}',
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 14),
              RouteSummary(
                pickup: r.request.pickup.name,
                destination: r.request.destination.name,
              ),
              const SizedBox(height: 12),
              _line(ctx.tr('driver'), r.driver.name),
              _line(
                ctx.tr('car'),
                '${r.driver.vehicle.title} · ${r.driver.vehicle.plate}',
              ),
              _line(ctx.tr('distance'), km(r.request.route.distanceKm)),
              _line(
                ctx.tr('payment'),
                paymentTypeLabel(ctx, r.request.payment),
              ),
              _line(ctx.tr('fare'), money(r.price)),
              if (r.tip > 0) _line(ctx.tr('tip'), money(r.tip)),
              const Divider(height: 20),
              _line(ctx.tr('total'), money(r.price + r.tip), bold: true),
              if (r.rating != null)
                _line(ctx.tr('your_rating'), '★' * r.rating!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(a, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            b,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = ride.status == RideStatus.cancelled;
    return CardBox(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${dayMonth(ride.createdAt)} · ${hhmm(ride.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              if (cancelled)
                Pill(
                  context.tr('cancelled'),
                  color: AppColors.dangerSoft,
                  textColor: AppColors.danger,
                )
              else if (ride.isActive)
                Pill(context.tr('in_progress'))
              else
                Text(
                  money(ride.price + ride.tip),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _place(Icons.circle, AppColors.pickup, ride.request.pickup.name),
          const SizedBox(height: 6),
          _place(
            Icons.circle,
            AppColors.destination,
            ride.request.destination.name,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Avatar(ride.driver.name, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ride.driver.name} · ${ride.driver.vehicle.title}',
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
    );
  }

  Widget _place(IconData icon, Color color, String text) => Row(
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}
