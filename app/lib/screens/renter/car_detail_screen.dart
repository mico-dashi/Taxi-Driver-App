import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/rental_widgets.dart';
import 'book_car_screen.dart';

class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.car});

  final Car car;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  final _map = MapController();

  Car get car => widget.car;

  Future<void> _dates() async {
    final app = context.read<AppState>();
    final r = await pickRentalDates(
      context,
      start: app.searchStart,
      end: app.searchEnd,
    );
    if (r != null) app.setSearch(start: r.$1, end: r.$2);
  }

  Future<void> _directions() async {
    final p = car.location.point;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final days = rentalDays(app.searchStart, app.searchEnd);
    final quote = Pricing.quote(
      perDay: car.pricePerDay,
      days: days,
      deposit: car.deposit,
      promoPercent: app.promoPercent,
    );
    final tooShort = days < car.minDays;
    return Scaffold(
      appBar: AppBar(title: Text(car.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1F3F6), Color(0xFFDDE2E9)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: RotatedBox(
              quarterTurns: 1,
              child: CarTopView(color: Color(car.colorValue), size: 230),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            car.make.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.inkFaint,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${car.model} · ${car.year}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Plate(car.plate),
            ],
          ),
          const SizedBox(height: 4),
          Rating(car.rating, trips: car.trips),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fact(
                Icons.settings_rounded,
                transmissionLabel(context, car.transmission),
              ),
              _fact(
                Icons.local_gas_station_rounded,
                fuelLabel(context, car.fuel),
              ),
              _fact(
                Icons.person_outline_rounded,
                context.tr('n_seats', {'n': '${car.seats}'}),
              ),
              _fact(
                Icons.speed_rounded,
                context.tr('km_per_day', {'n': '${car.kmPerDay}'}),
              ),
              _fact(
                categoryIcon(car.categoryId),
                context.tr(Pricing.byId(car.categoryId).nameKey),
              ),
            ],
          ),
          SectionLabel(context.tr('owner')),
          CardBox(
            child: Row(
              children: [
                Avatar(car.ownerName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VerifiedName(car.ownerName),
                      Rating(car.ownerRating),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (car.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(car.description, style: const TextStyle(height: 1.4)),
          ],
          SectionLabel(context.tr('pickup_location')),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 170,
              child: AppMap(
                controller: _map,
                center: car.location.point,
                zoom: 14.5,
                interactive: false,
                children: [
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: car.location.point,
                        width: 40,
                        height: 60,
                        child: CarTopView(
                          color: Color(car.colorValue),
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    car.location.name,
                    car.location.subtitle,
                  ].where((s) => s.isNotEmpty).join(', '),
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
              TextButton.icon(
                onPressed: _directions,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(context.tr('directions')),
              ),
            ],
          ),
          if (car.delivery)
            Text(
              car.deliveryFee == 0
                  ? context.tr('delivery_free_desc')
                  : context.tr('delivery_desc', {'p': money(car.deliveryFee)}),
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          SectionLabel(context.tr('rental_terms')),
          CardBox(
            child: Column(
              children: [
                _term(
                  Icons.account_balance_wallet_outlined,
                  context.tr('deposit'),
                  money(car.deposit),
                ),
                _term(
                  Icons.event_available_rounded,
                  context.tr('min_rental'),
                  context.tr('n_days', {'n': '${car.minDays}'}),
                ),
                _term(
                  Icons.speed_rounded,
                  context.tr('mileage'),
                  context.tr('km_per_day', {'n': '${car.kmPerDay}'}),
                ),
                _term(
                  Icons.local_gas_station_outlined,
                  context.tr('fuel_policy'),
                  context.tr('fuel_policy_value'),
                ),
                _term(
                  Icons.badge_outlined,
                  context.tr('requirements'),
                  context.tr('requirements_value'),
                ),
              ],
            ),
          ),
          SectionLabel(context.tr('your_dates')),
          DatesField(start: app.searchStart, end: app.searchEnd, onTap: _dates),
          const SizedBox(height: 12),
          if (tooShort)
            Pill(
              context.tr('min_days_note', {'n': '${car.minDays}'}),
              color: AppColors.dangerSoft,
              textColor: AppColors.danger,
            )
          else
            PriceBreakdown(quote: quote),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: money(car.pricePerDay),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: context.tr('per_day_short'),
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    if (!tooShort)
                      Text(
                        '${money(quote.total)} ${context.tr('in_total')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 52),
                ),
                onPressed: tooShort
                    ? _dates
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookCarScreen(car: car),
                        ),
                      ),
                child: Text(context.tr(tooShort ? 'change_dates' : 'book_now')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _term(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.inkSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.inkSoft)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
