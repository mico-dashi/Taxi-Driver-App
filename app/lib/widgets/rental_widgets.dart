import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/pricing.dart';
import 'common.dart';

/// Lets the user choose pickup and return days, then the pickup hour.
/// Returns (start, end) or null when cancelled.
Future<(DateTime, DateTime)?> pickRentalDates(
  BuildContext context, {
  required DateTime start,
  required DateTime end,
}) async {
  final today = DateTime.now();
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(today.year, today.month, today.day),
    lastDate: today.add(const Duration(days: 365)),
    initialDateRange: DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    ),
    helpText: context.tr('choose_dates'),
    saveText: context.tr('continue'),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          secondaryContainer: AppColors.primarySoft,
        ),
      ),
      child: child!,
    ),
  );
  if (range == null || !context.mounted) return null;
  final hour = await showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.tr('pickup_time'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              ctx.tr('pickup_time_desc'),
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var h = 7; h <= 21; h++)
                  ChoiceChip(
                    label: Text('${h.toString().padLeft(2, '0')}:00'),
                    selected: h == start.hour,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => Navigator.pop(ctx, h),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (hour == null) return null;
  var from = DateTime(
    range.start.year,
    range.start.month,
    range.start.day,
    hour,
  );
  var to = DateTime(range.end.year, range.end.month, range.end.day, hour);
  // Today with an hour already past: start in the next full hour.
  if (from.isBefore(DateTime.now())) {
    final n = DateTime.now().add(const Duration(hours: 1));
    from = DateTime(n.year, n.month, n.day, n.hour);
  }
  if (!to.isAfter(from)) to = from.add(const Duration(days: 1));
  return (from, to);
}

/// Tappable "pickup → return" box.
class DatesField extends StatelessWidget {
  const DatesField({
    super.key,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime start;
  final DateTime end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _col(context, context.tr('pickup'), start)),
          Column(
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.inkFaint,
              ),
              Text(
                context.tr('n_days', {'n': '${rentalDays(start, end)}'}),
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(child: _col(context, context.tr('return'), end)),
        ],
      ),
    );
  }

  Widget _col(BuildContext context, String label, DateTime t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
      ),
      Text(
        context.day(t),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      Text(
        hhmm(t),
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
    ],
  );
}

String transmissionLabel(BuildContext context, Transmission t) =>
    context.tr(t == Transmission.automatic ? 'automatic' : 'manual');

String fuelLabel(BuildContext context, Fuel f) => context.tr('fuel_${f.name}');

/// Car card for lists: drawing, make/model, specs, owner, price per day.
class CarListingCard extends StatelessWidget {
  const CarListingCard({
    super.key,
    required this.car,
    required this.onTap,
    this.distanceLabel,
  });

  final Car car;
  final VoidCallback onTap;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.make.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    Text(
                      '${car.model} · ${car.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _spec(
                          Icons.settings_rounded,
                          transmissionLabel(context, car.transmission),
                        ),
                        _spec(
                          Icons.local_gas_station_rounded,
                          fuelLabel(context, car.fuel),
                        ),
                        _spec(Icons.person_outline_rounded, '${car.seats}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CarBadge.of(car, size: 58),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 15,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  [car.location.name, ?distanceLabel].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Rating(car.rating),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: money(car.pricePerDay),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: context.tr('per_day_short'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (car.delivery) ...[
            const SizedBox(height: 8),
            Pill(
              car.deliveryFee == 0
                  ? context.tr('free_delivery')
                  : context.tr('delivery_for', {'p': money(car.deliveryFee)}),
              color: AppColors.primarySoft,
              textColor: AppColors.primaryDark,
              dot: false,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _spec(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.inkSoft),
      const SizedBox(width: 3),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
    ],
  );
}

/// Line-by-line price: days x price, long-stay discount, promo, delivery,
/// total, and the refundable deposit.
class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({super.key, required this.quote});

  final RentalQuote quote;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return CardBox(
      child: Column(
        children: [
          _row(
            '${money(q.perDay)} × ${context.tr('n_days', {'n': '${q.days}'})}',
            money(q.base),
          ),
          if (q.longStayDiscount > 0)
            _row(
              context.tr('long_stay_discount'),
              '-${money(q.longStayDiscount)}',
              color: AppColors.success,
            ),
          if (q.promoDiscount > 0)
            _row(
              context.tr('promo_discount'),
              '-${money(q.promoDiscount)}',
              color: AppColors.success,
            ),
          if (q.deliveryFee > 0)
            _row(context.tr('delivery'), money(q.deliveryFee)),
          const Divider(height: 20),
          _row(context.tr('total'), money(q.total), bold: true),
          const SizedBox(height: 6),
          _row(
            context.tr('deposit_refundable'),
            money(q.deposit),
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }

  static Widget _row(String a, String b, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                a,
                style: TextStyle(
                  color: color ?? (bold ? AppColors.ink : AppColors.inkSoft),
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
              ),
            ),
            Text(
              b,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 18 : 14,
              ),
            ),
          ],
        ),
      );
}

(Color, Color) statusColors(BookingStatus s) => switch (s) {
  BookingStatus.requested ||
  BookingStatus.countered => (AppColors.primarySoft, AppColors.primaryDark),
  BookingStatus.confirmed => (const Color(0xFFE3ECFF), AppColors.verified),
  BookingStatus.active => (AppColors.successSoft, AppColors.success),
  BookingStatus.completed => (AppColors.background, AppColors.inkSoft),
  _ => (AppColors.dangerSoft, AppColors.danger),
};

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill(this.status, {super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(status);
    return Pill(context.tr('status_${status.name}'), color: bg, textColor: fg);
  }
}

/// Compact booking row used in the renter's and the owner's lists.
class BookingTile extends StatelessWidget {
  const BookingTile({
    super.key,
    required this.booking,
    required this.onTap,
    required this.asOwner,
  });

  final Booking booking;
  final VoidCallback onTap;
  final bool asOwner;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final who = asOwner ? b.renterName : b.car.ownerName;
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CarBadge.of(b.car, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.car.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.dayRange(b.start, b.end),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                if (who.isNotEmpty)
                  Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BookingStatusPill(b.status),
              const SizedBox(height: 6),
              Text(
                money(Pricing.quoteFor(b).total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
