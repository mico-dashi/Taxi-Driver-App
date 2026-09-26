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
import '../../widgets/car_art.dart';
import '../../widgets/common.dart';
import '../../widgets/design.dart';
import '../../widgets/glass.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final category = Pricing.byId(car.categoryId);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('details'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.near_me_outlined,
                    tooltip: context.tr('directions'),
                    onTap: _directions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 200),
                children: [
                  _hero(width),
                  CardBox(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            MakeBadge(car, size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${car.model} · ${car.year}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${car.make} · ${money(car.pricePerDay)}${context.tr('per_day_short')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FavoriteButton(carId: car.id, size: 44),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SpecTile(
                                compact: true,
                                icon: Icons.directions_car_outlined,
                                title: transmissionLabel(
                                  context,
                                  car.transmission,
                                ),
                                caption: context.tr('gearbox'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SpecTile(
                                compact: true,
                                icon: Icons.airline_seat_recline_normal_rounded,
                                title: '${car.seats}',
                                caption: context.tr('seats'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Rating(car.rating, trips: car.trips),
                            ),
                            Plate(car.plate),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      SpecTile(
                        icon: Icons.local_gas_station_outlined,
                        title: fuelLabel(context, car.fuel),
                        caption: context.tr('fuel'),
                        glow: true,
                      ),
                      SpecTile(
                        icon: Icons.speed_rounded,
                        title: context.tr('km_per_day', {
                          'n': '${car.kmPerDay}',
                        }),
                        caption: context.tr('mileage'),
                      ),
                      SpecTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: money(car.deposit),
                        caption: context.tr('deposit'),
                      ),
                      SpecTile(
                        icon: Icons.event_available_rounded,
                        title: context.tr('n_days', {'n': '${car.minDays}'}),
                        caption: context.tr('min_rental'),
                        glow: true,
                      ),
                      SpecTile(
                        icon: categoryIcon(car.categoryId),
                        title: context.tr(category.nameKey),
                        caption: context.tr('car_type'),
                        glow: true,
                      ),
                      SpecTile(
                        icon: Icons.calendar_today_outlined,
                        title: '${car.year}',
                        caption: context.tr('year'),
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
                    Text(
                      car.description,
                      style: const TextStyle(
                        height: 1.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  SectionLabel(context.tr('pickup_location')),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
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
                          : context.tr('delivery_desc', {
                              'p': money(car.deliveryFee),
                            }),
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  SectionLabel(context.tr('rental_terms')),
                  CardBox(
                    child: Column(
                      children: [
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
                  DatesField(
                    start: app.searchStart,
                    end: app.searchEnd,
                    onTap: _dates,
                  ),
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
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Glass(
          radius: 34,
          blur: 26,
          strength: 1.15,
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.paddingOf(context).bottom * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                child: Row(
                  children: [
                    PerDayPrice(car.pricePerDay),
                    const SizedBox(width: 12),
                    if (!tooShort)
                      Expanded(
                        child: Text(
                          '${money(quote.total)} ${context.tr('in_total')}',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SlideAction(
                label: context.tr(tooShort ? 'change_dates' : 'slide_to_book'),
                icon: tooShort
                    ? Icons.calendar_month_rounded
                    : Icons.check_rounded,
                onSubmit: tooShort
                    ? _dates
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookCarScreen(car: car),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(double width) {
    if (car.photos.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 14),
        child: PhotoGallery(photos: car.photos, height: 260),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Hero(
        tag: 'car-${car.id}',
        child: Glass(
          height: 240,
          radius: 30,
          shadow: false,
          child: CarPlaceholder.of(car),
        ),
      ),
    );
  }

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
