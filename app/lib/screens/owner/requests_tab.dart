import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/rental_widgets.dart';
import '../common/booking_screen.dart';

/// Owner's inbox: new requests first, then upcoming handovers, cars out,
/// and history.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, required this.onAddCar});

  final VoidCallback onAddCar;

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<Booking>? _bookings;
  List<Car> _cars = [];
  StreamSubscription<List<Booking>>? _sub;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    final backend = context.read<AppState>().backend;
    _sub = backend.watchOwnerBookings().listen((list) {
      if (!mounted) return;
      final newCount = list
          .where((b) => b.status == BookingStatus.requested)
          .length;
      final oldCount =
          _bookings?.where((b) => b.status == BookingStatus.requested).length ??
          newCount;
      if (newCount > oldCount) HapticFeedback.mediumImpact();
      setState(() => _bookings = list);
    });
    _loadCars();
  }

  Future<void> _loadCars() async {
    final cars = await context.read<AppState>().backend.myCars();
    if (mounted) setState(() => _cars = cars);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _act(String id, Future<void> Function() f, String? done) async {
    setState(() => _busy.add(id));
    try {
      await f();
      if (done != null && mounted) showInfo(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _open(Booking b) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => BookingScreen(initial: b)));

  @override
  Widget build(BuildContext context) {
    final all = _bookings ?? const <Booking>[];
    final fresh = all
        .where((b) => b.status == BookingStatus.requested)
        .toList();
    final countered = all
        .where((b) => b.status == BookingStatus.countered)
        .toList();
    final upcoming =
        all.where((b) => b.status == BookingStatus.confirmed).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final out = all.where((b) => b.status == BookingStatus.active).toList();
    final history = all.where((b) => b.isFinished).toList();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadCars,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('tab_requests'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (context.read<AppState>().backend.isDemo)
                  const Pill(
                    'DEMO',
                    color: AppColors.primarySoft,
                    textColor: AppColors.ink,
                    dot: false,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_cars.isEmpty)
              CardBox(
                color: AppColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('no_cars_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(context.tr('no_cars_body')),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: widget.onAddCar,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.tr('add_car')),
                    ),
                  ],
                ),
              )
            else if (_bookings != null && all.isEmpty)
              CardBox(
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr('no_requests_yet'))),
                  ],
                ),
              ),
            if (fresh.isNotEmpty) SectionLabel(context.tr('new_requests')),
            for (final b in fresh)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RequestCard(
                  booking: b,
                  busy: _busy.contains(b.id),
                  onOpen: () => _open(b),
                  onAccept: () => _act(
                    b.id,
                    () => context.read<AppState>().backend.acceptBooking(b.id),
                    context.tr('booking_confirmed'),
                  ),
                  onDecline: () => _act(
                    b.id,
                    () => context.read<AppState>().backend.declineBooking(b.id),
                    null,
                  ),
                  onCounter: () async {
                    final price = await showCounterSheet(context, b);
                    if (price == null || !context.mounted) return;
                    await _act(
                      b.id,
                      () => context.read<AppState>().backend.counterBooking(
                        b.id,
                        price,
                      ),
                      context.tr('counter_sent'),
                    );
                  },
                ),
              ),
            ..._section(context.tr('waiting_renter'), countered),
            ..._section(context.tr('upcoming_handovers'), upcoming),
            ..._section(context.tr('cars_out'), out),
            ..._section(context.tr('history'), history.take(15).toList()),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<Booking> list) => [
    if (list.isNotEmpty) SectionLabel(title),
    for (final b in list)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BookingTile(booking: b, asOwner: true, onTap: () => _open(b)),
      ),
  ];
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.booking,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  final Booking booking;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final below = b.offeredPerDay < b.car.pricePerDay;
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(b.renterName, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.renterName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Rating(b.renterRating),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${money(b.offeredPerDay)}${context.tr('per_day_short')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (below)
                        Text(
                          context.tr('you_ask', {
                            'p': money(b.car.pricePerDay),
                          }),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryDark,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CarBadge.of(b.car, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.car.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${context.dayRange(b.start, b.end)} · ${context.tr('n_days', {'n': '${b.days}'})}',
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Pill(
                    '${context.tr('total')}: ${money(Pricing.quoteFor(b).total)}',
                    color: AppColors.background,
                    textColor: AppColors.ink,
                    dot: false,
                  ),
                  Pill(
                    paymentTypeLabel(context, b.payment),
                    color: AppColors.background,
                    textColor: AppColors.inkSoft,
                    dot: false,
                  ),
                  if (b.pickup == Pickup.delivery)
                    Pill(
                      context.tr('delivery'),
                      color: AppColors.primarySoft,
                      textColor: AppColors.primaryDark,
                      dot: false,
                    ),
                ],
              ),
              if (b.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '“${b.note}”',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: AppColors.dangerSoft,
                        foregroundColor: AppColors.danger,
                        side: BorderSide.none,
                      ),
                      child: Text(context.tr('decline')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onCounter,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(context.tr('counter_short')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onAccept,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(context.tr('accept')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
