import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/pricing.dart';

import '../core/brands.dart';
import '../core/demo_photos.dart';
import 'car_art.dart';
import 'common.dart';
import 'design.dart';
import 'glass.dart';

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
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondaryContainer: AppColors.primarySoft,
          surface: AppColors.background,
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
              textColor: AppColors.primaryLight,
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

/// "Price /day" with the unit in a smaller grey font.
class PerDayPrice extends StatelessWidget {
  const PerDayPrice(this.amount, {super.key, this.fontSize = 20});

  final int amount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: money(amount),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          TextSpan(
            text: context.tr('per_day_short'),
            style: TextStyle(
              fontSize: fontSize * 0.55,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// The car's picture layer for cards: the cover photo filling the card, or
/// the drawing floating in the top part of the glass.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.car, required this.panelHeight});

  final Car car;

  /// Height of the glass info panel at the bottom, kept clear.
  final double panelHeight;

  @override
  Widget build(BuildContext context) {
    if (car.photos.isNotEmpty) {
      return Positioned.fill(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CarPhoto(car.photos.first),
            // Darken the bottom a little so the glass panel reads well.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x66000000)],
                  stops: [0.4, 1],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      bottom: panelHeight,
      child: CarPlaceholder.of(car),
    );
  }
}

/// Card for the "Top trends" carousel: photo (or drawing), brand logo,
/// heart, and a frosted panel with name, place, rating and price.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      width: 264,
      radius: 30,
      onTap: onTap,
      grouped: true,
      shadow: false,
      child: Stack(
        children: [
          const SizedBox.expand(),
          _CardImage(car: car, panelHeight: 84),
          // The big logo already shows the brand when there is no photo.
          if (car.photos.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: GlassBrand(make: car.make, size: 42),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: FavoriteButton(carId: car.id, size: 42),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Glass(
              radius: 22,
              blur: 18,
              strength: 1.1,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 12,
                              color: AppColors.inkSoft,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                car.location.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Rating(car.rating, trips: car.trips),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(car.pricePerDay),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.tr('per_day_long'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkSoft,
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
    );
  }
}

/// Big "Choose a car" card: photo (or drawing) with the brand logo and a
/// heart on top, and a frosted panel with make, model, specs, price and a
/// red arrow.
class ChooseCarCard extends StatelessWidget {
  const ChooseCarCard({
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
    return LayoutBuilder(
      builder: (context, box) => Glass(
        height: 236,
        radius: 32,
        onTap: onTap,
        grouped: true,
        shadow: false,
        child: Stack(
          children: [
            _CardImage(car: car, panelHeight: 92),
            // The big logo already shows the brand when there is no photo.
            if (car.photos.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                child: GlassBrand(make: car.make, size: 46),
              ),
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                children: [
                  Glass(
                    radius: 16,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          car.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FavoriteButton(carId: car.id, size: 40),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Glass(
                radius: 24,
                blur: 18,
                strength: 1.1,
                shadow: false,
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.make,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${car.model} · ${car.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              transmissionLabel(context, car.transmission),
                              fuelLabel(context, car.fuel),
                              ?distanceLabel,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
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
                        Text(
                          money(car.pricePerDay),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          context.tr('per_day_long'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: redDroplet,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipeable car photos with glass page dots.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.photos, this.height = 240});

  final List<String> photos;
  final double height;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: n,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (_, i) => CarPhoto(widget.photos[i]),
            ),
            if (creditFor(widget.photos[_page]) case final credit?)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(credit.pageUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Glass(
                    radius: 12,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '📷 Wikimedia Commons · ${credit.license}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            if (n > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Glass(
                    radius: 12,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < n; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Row of brand logos to filter cars; "All" first.
class BrandFilterRow extends StatelessWidget {
  const BrandFilterRow({
    super.key,
    required this.makes,
    required this.selected,
    required this.onSelect,
  });

  /// Makes to offer, e.g. the ones among the search results.
  final List<String> makes;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String? make, Widget logo, String label) {
      final on = make == null ? selected == null : selected == make;
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onSelect(make),
            child: Column(
              children: [
                Glass(
                  circle: true,
                  width: 60,
                  height: 60,
                  shadow: false,
                  grouped: true,
                  selected: on,
                  tint: on ? AppColors.primary : null,
                  child: Center(child: logo),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 66,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          item(
            null,
            const Icon(Icons.apps_rounded, size: 26),
            context.tr('all_brands'),
          ),
          for (final m in makes)
            item(m, BrandLogo(make: m, size: 28), brandFor(m)?.name ?? m),
        ],
      ),
    );
  }
}

/// Makes among [cars], most common first.
List<String> makesOf(Iterable<Car> cars) {
  final counts = <String, int>{};
  for (final c in cars) {
    final key = brandFor(c.make)?.name ?? c.make;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
}

/// Whether [car] is of the brand shown as [make] in a [BrandFilterRow].
bool isMake(Car car, String make) =>
    (brandFor(car.make)?.name ?? car.make) == make;

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
  BookingStatus.countered => (AppColors.primarySoft, AppColors.primaryLight),
  BookingStatus.confirmed => (AppColors.infoSoft, AppColors.info),
  BookingStatus.active => (AppColors.successSoft, AppColors.success),
  BookingStatus.completed => (AppColors.surfaceHigh, AppColors.inkSoft),
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
