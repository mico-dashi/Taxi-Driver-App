import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/rental_widgets.dart';
import '../common/where_to_sheet.dart';
import 'car_detail_screen.dart';
import 'search_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenRentals});

  final VoidCallback onOpenRentals;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _category;
  Future<List<Car>>? _nearby;
  String? _nearbyKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppState>();
    final key =
        '${app.effectiveSearchPlace.point}|${app.searchStart}|${app.searchEnd}';
    if (_nearbyKey != key) {
      _nearbyKey = key;
      _load();
    }
  }

  void _load() {
    final app = context.read<AppState>();
    _nearby = app.backend.searchCars(
      near: app.effectiveSearchPlace.point,
      start: app.searchStart,
      end: app.searchEnd,
    );
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('good_morning');
    if (h < 18) return context.tr('good_afternoon');
    return context.tr('good_evening');
  }

  Future<void> _pickPlace() async {
    final place = await showWhereTo(context, titleKey: 'where_need_car');
    if (place == null || !mounted) return;
    final app = context.read<AppState>();
    app.addRecent(place);
    app.setSearch(place: place);
  }

  Future<void> _pickDates() async {
    final app = context.read<AppState>();
    final r = await pickRentalDates(
      context,
      start: app.searchStart,
      end: app.searchEnd,
    );
    if (r != null) app.setSearch(start: r.$1, end: r.$2);
  }

  void _search() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(initialCategory: _category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _nearby;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Avatar(user?.name ?? '', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting(context)}, ${user?.firstName ?? ''}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.tr('home_subtitle'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (app.backend.isDemo)
                  const Pill(
                    'DEMO',
                    color: AppColors.primarySoft,
                    textColor: AppColors.ink,
                    dot: false,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // Search card: where + when + type.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardBox(
                    onTap: _pickPlace,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('where'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkFaint,
                                ),
                              ),
                              Text(
                                app.effectiveSearchPlace.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.inkFaint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  DatesField(
                    start: app.searchStart,
                    end: app.searchEnd,
                    onTap: _pickDates,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip(null, context.tr('all_cars'), Icons.apps_rounded),
                        for (final c in Pricing.categories)
                          _chip(
                            c.id,
                            context.tr(c.nameKey),
                            categoryIcon(c.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(context.tr('search_cars')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PromoBanner(
              applied: app.promoCode != null,
              onApply: () async {
                final pct = await app.applyPromo(AppConfig.promoCode);
                if (!context.mounted) return;
                showInfo(
                  context,
                  pct > 0
                      ? context.tr('promo_applied', {'p': '$pct'})
                      : context.tr('promo_invalid'),
                );
              },
            ),
            SectionLabel(
              context.tr('cars_near', {'place': app.effectiveSearchPlace.name}),
            ),
            FutureBuilder<List<Car>>(
              future: _nearby,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final cars = snap.data!;
                if (cars.isEmpty) {
                  return CardBox(child: Text(context.tr('no_cars_found')));
                }
                return Column(
                  children: [
                    for (final c in cars.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CarListingCard(
                          car: c,
                          distanceLabel: _distance(
                            app.effectiveSearchPlace.point,
                            c,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CarDetailScreen(car: c),
                            ),
                          ),
                        ),
                      ),
                    if (cars.length > 6)
                      OutlinedButton(
                        onPressed: _search,
                        child: Text(
                          context.tr('see_all_n', {'n': '${cars.length}'}),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String? id, String label, IconData icon) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.background,
        side: BorderSide.none,
        onSelected: (_) => setState(() => _category = id),
      ),
    );
  }
}

/// "2,4 km" from the searched place.
String distanceLabel(LatLng from, Car car) {
  const d = Distance();
  return km(d.as(LengthUnit.Meter, from, car.location.point) / 1000);
}

String _distance(LatLng from, Car car) => distanceLabel(from, car);

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.applied, required this.onApply});

  final bool applied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFFD45C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('limited_offer'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('promo_title', {'p': '${AppConfig.promoPercent}'}),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: applied ? null : onApply,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          applied
                              ? context.tr('promo_active')
                              : AppConfig.promoCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          applied
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.car_rental_rounded, size: 84, color: AppColors.ink),
        ],
      ),
    );
  }
}
