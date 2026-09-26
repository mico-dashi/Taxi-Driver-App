import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/backend.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/car_art.dart';
import '../../widgets/common.dart';
import '../../widgets/design.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/rental_widgets.dart';
import '../chat/chat_screen.dart';

/// One booking, seen by the renter or by the owner, with the next action.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.initial});

  final Booking initial;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Booking _b = widget.initial;
  StreamSubscription<Booking>? _sub;
  final _map = MapController();
  bool _busy = false;
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = context.read<AppState>().backend.watchBooking(_b.id).listen((b) {
      if (!mounted) return;
      if (b.status != _b.status) HapticFeedback.mediumImpact();
      setState(() => _b = b);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _comment.dispose();
    super.dispose();
  }

  bool get _asOwner =>
      _b.car.ownerId == context.read<AppState>().backend.currentUserId;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) showInfo(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reasons = _asOwner
        ? const ['reason_car_unavailable', 'reason_other']
        : const [
            'reason_changed_plans',
            'reason_found_other',
            'reason_price',
            'reason_other',
          ];
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
              const SizedBox(height: 8),
              for (final r in reasons)
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
    final backend = context.read<AppState>().backend;
    await _run(() => backend.cancelBooking(_b.id, reason));
  }

  Future<void> _counter() async {
    final price = await showCounterSheet(context, _b);
    if (price == null || !mounted) return;
    final backend = context.read<AppState>().backend;
    await _run(
      () => backend.counterBooking(_b.id, price),
      done: context.tr('counter_sent'),
    );
  }

  void _chat() {
    final peer = _asOwner ? _b.renterName : _b.car.ownerName;
    final phone = _asOwner ? _b.renterPhone : _b.car.ownerPhone;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          bookingId: _b.id,
          peerName: peer,
          peerPhone: _b.isUpcomingOrActive ? phone : '',
        ),
      ),
    );
  }

  Future<void> _call() async {
    final phone = _asOwner ? _b.renterPhone : _b.car.ownerPhone;
    if (phone.isEmpty || !await launchUrl(Uri(scheme: 'tel', path: phone))) {
      if (mounted) showInfo(context, context.tr('cannot_call'));
    }
  }

  Future<void> _directions() async {
    final p = _b.car.location.point;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final backend = context.read<AppState>().backend;
    final quote = Pricing.quoteFor(b);
    final peerName = _asOwner ? b.renterName : b.car.ownerName;
    final peerRating = _asOwner ? b.renterRating : b.car.ownerRating;
    return Scaffold(
      appBar: AppBar(
        title: Text(b.car.title),
        actions: [
          if (!b.isFinished || b.status == BookingStatus.completed)
            IconButton(
              onPressed: _chat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: context.tr('message'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _statusCard(backend),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CarImage(car: b.car, width: 250, height: 150),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    MakeBadge(b.car, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.car.title} · ${b.car.year}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),

                          Wrap(
                            spacing: 8,

                            runSpacing: 6,

                            children: [
                              Plate(b.car.plate),

                              BookingStatusPill(b.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DatesField(start: b.start, end: b.end, onTap: () {}),
          SectionLabel(context.tr(_asOwner ? 'renter' : 'owner')),
          CardBox(
            child: Row(
              children: [
                Avatar(peerName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VerifiedName(
                        peerName.isEmpty ? context.tr('renter') : peerName,
                      ),
                      Rating(peerRating),
                    ],
                  ),
                ),
                if (b.isUpcomingOrActive)
                  IconButton.filledTonal(
                    tooltip: context.tr('call'),
                    onPressed: _call,
                    icon: const Icon(Icons.call_outlined),
                  ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: context.tr('message'),
                  onPressed: _chat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ],
            ),
          ),
          if (b.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            CardBox(
              color: AppColors.primarySoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b.note)),
                ],
              ),
            ),
          ],
          SectionLabel(
            context.tr(
              b.pickup == Pickup.delivery
                  ? 'delivery_address'
                  : 'pickup_location',
            ),
          ),
          if (b.pickup == Pickup.delivery)
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b.deliveryAddress)),
                ],
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 160,
                child: AppMap(
                  controller: _map,
                  center: b.car.location.point,
                  zoom: 15,
                  interactive: false,
                  children: [
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: b.car.location.point,
                          width: 40,
                          height: 60,
                          child: CarTopView(
                            color: Color(b.car.colorValue),
                            size: 46,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.car.location.name,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ),
                if (!_asOwner)
                  TextButton.icon(
                    onPressed: _directions,
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: Text(context.tr('directions')),
                  ),
              ],
            ),
          ],
          SectionLabel(context.tr('price')),
          PriceBreakdown(quote: quote),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                context.tr('payment'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const Spacer(),
              Text(
                paymentTypeLabel(context, b.payment),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (b.isOpen || b.status == BookingStatus.confirmed) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: _busy ? null : _cancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(
                context.tr(
                  b.isOpen && !_asOwner ? 'cancel_request' : 'cancel_booking',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(Backend backend) {
    final b = _b;
    final (bg, fg) = statusColors(b.status);
    String title;
    String body;
    List<Widget> actions = [];
    final owner = b.car.ownerName.split(' ').first;
    final renter = b.renterName.split(' ').first;

    Widget primary(String label, VoidCallback onTap) => ElevatedButton(
      onPressed: _busy ? null : onTap,
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );

    switch ((b.status, _asOwner)) {
      case (BookingStatus.requested, false):
        title = context.tr('st_requested_title');
        body = context.tr('st_requested_body', {'name': owner});
        actions = [
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceHigh,
          ),
        ];
      case (BookingStatus.requested, true):
        title = context.tr('st_new_request_title', {'name': renter});
        body = context.tr('st_new_request_body', {
          'offer': money(b.offeredPerDay),
          'listed': money(b.car.pricePerDay),
        });
        actions = [
          primary(
            '${context.tr('accept')} · ${money(Pricing.quoteFor(b).total)}',
            () => _run(
              () => backend.acceptBooking(b.id),
              done: context.tr('booking_confirmed'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _counter,
                  child: Text(context.tr('counter_offer')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => backend.declineBooking(b.id)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.dangerSoft,
                    foregroundColor: AppColors.danger,
                    side: BorderSide.none,
                  ),
                  child: Text(context.tr('decline')),
                ),
              ),
            ],
          ),
        ];
      case (BookingStatus.countered, false):
        title = context.tr('st_countered_title', {'name': owner});
        body = context.tr('st_countered_body', {
          'price': money(b.counterPerDay ?? b.offeredPerDay),
          'offer': money(b.offeredPerDay),
        });
        actions = [
          primary(
            '${context.tr('accept')} · ${money(Pricing.quoteFor(b).total)}',
            () => _run(
              () => backend.acceptCounter(b.id),
              done: context.tr('booking_confirmed'),
            ),
          ),
        ];
      case (BookingStatus.countered, true):
        title = context.tr('st_counter_sent_title');
        body = context.tr('st_counter_sent_body', {
          'name': renter,
          'price': money(b.counterPerDay ?? 0),
        });
      case (BookingStatus.confirmed, false):
        title = context.tr('st_confirmed_title');
        body = context.tr('st_confirmed_body', {
          'name': owner,
          'when': context.dayTime(b.start),
          'deposit': money(b.car.deposit),
        });
        actions = [
          primary(
            context.tr('i_picked_up'),
            () => _run(() => backend.markPickedUp(b.id)),
          ),
        ];
      case (BookingStatus.confirmed, true):
        title = context.tr('st_owner_confirmed_title');
        body = context.tr('st_owner_confirmed_body', {
          'name': renter,
          'when': context.dayTime(b.start),
        });
        actions = [
          primary(
            context.tr('i_handed_over'),
            () => _run(() => backend.markPickedUp(b.id)),
          ),
        ];
      case (BookingStatus.active, false):
        title = context.tr('st_active_title');
        body = context.tr('st_active_body', {'when': context.dayTime(b.end)});
        actions = [
          primary(
            context.tr('i_returned'),
            () => _run(() => backend.markReturned(b.id)),
          ),
        ];
      case (BookingStatus.active, true):
        title = context.tr('st_owner_active_title', {'name': renter});
        body = context.tr('st_owner_active_body', {
          'when': context.dayTime(b.end),
        });
        actions = [
          primary(
            context.tr('car_returned'),
            () => _run(() => backend.markReturned(b.id)),
          ),
        ];
      case (BookingStatus.completed, false):
        title = context.tr('st_completed_title');
        body = b.rating == null
            ? context.tr('st_rate_body', {'name': owner})
            : context.tr('thanks_rating');
        if (b.rating == null) actions = _ratingForm(backend);
      case (BookingStatus.completed, true):
        title = context.tr('st_completed_title');
        body = context.tr('st_owner_completed_body', {
          'total': money(Pricing.quoteFor(b).total),
        });
      case (BookingStatus.declined, _):
        title = context.tr('status_declined');
        body = context.tr(
          _asOwner ? 'st_owner_declined_body' : 'st_declined_body',
        );
      case (BookingStatus.cancelled, _):
        title = context.tr('status_cancelled');
        body = b.cancelReason == 'renter_declined_counter'
            ? context.tr('st_counter_declined_body', {'name': renter})
            : context.tr('st_cancelled_body');
      case (BookingStatus.expired, _):
        title = context.tr('status_expired');
        body = context.tr('st_expired_body');
    }
    if (!_asOwner &&
        (b.status == BookingStatus.declined ||
            b.status == BookingStatus.cancelled ||
            b.status == BookingStatus.expired)) {
      actions = [
        primary(
          context.tr('find_another_car'),
          () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_statusIcon(b.status), color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.35)),
          if (actions.isNotEmpty) ...[const SizedBox(height: 14), ...actions],
        ],
      ),
    );
  }

  List<Widget> _ratingForm(Backend backend) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 34,
            onPressed: () => setState(() => _stars = i),
            icon: Icon(
              i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.primaryLight,
            ),
          ),
      ],
    ),
    TextField(
      controller: _comment,
      maxLines: 2,
      decoration: InputDecoration(hintText: context.tr('comment_hint')),
    ),
    const SizedBox(height: 10),
    ElevatedButton(
      onPressed: _busy
          ? null
          : () => _run(
              () => backend.rateBooking(
                _b.id,
                stars: _stars,
                comment: _comment.text.trim(),
              ),
              done: context.tr('thanks_rating'),
            ),
      child: Text(context.tr('submit_review')),
    ),
  ];

  static IconData _statusIcon(BookingStatus s) => switch (s) {
    BookingStatus.requested => Icons.hourglass_top_rounded,
    BookingStatus.countered => Icons.swap_horiz_rounded,
    BookingStatus.confirmed => Icons.event_available_rounded,
    BookingStatus.active => Icons.key_rounded,
    BookingStatus.completed => Icons.flag_rounded,
    _ => Icons.cancel_outlined,
  };
}

/// Owner picks a counter-offer per day (above the renter's offer).
Future<int?> showCounterSheet(BuildContext context, Booking b) {
  var price = b.car.pricePerDay > b.offeredPerDay
      ? b.car.pricePerDay
      : b.offeredPerDay + 200;
  return showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final q = Pricing.quote(
          perDay: price,
          days: b.days,
          deposit: b.car.deposit,
          deliveryFee: b.pickup == Pickup.delivery ? b.car.deliveryFee : 0,
          promoPercent: b.promoPercent,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.tr('counter_offer'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ctx.tr('counter_desc', {'offer': money(b.offeredPerDay)}),
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${money(price)}${ctx.tr('per_day_short')}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${money(q.total)} ${ctx.tr('in_total')}',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: context.tr('decrease'),
                      onPressed: price - 100 > b.offeredPerDay
                          ? () => setSheet(() => price -= 100)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: context.tr('increase'),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setSheet(() => price += 100),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, price),
                  child: Text(ctx.tr('send_counter')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
