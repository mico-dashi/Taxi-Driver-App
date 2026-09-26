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
import '../../widgets/design.dart';
import '../../widgets/glass.dart';
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
  String? _brand;
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
        builder: (_) => SearchScreen(
          initialCategory: _category == _favorites ? null : _category,
        ),
      ),
    );
  }

  void _open(Car car) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => CarDetailScreen(car: car)));

  List<Car> _chosen(AppState app, List<Car> cars) => [
    for (final c in cars)
      if ((_brand == null || isMake(c, _brand!)) &&
          switch (_category) {
            null => true,
            _favorites => app.isFavorite(c.id),
            final id => c.categoryId == id,
          })
        c,
  ];

  /// Best rated cars with the most rentals first.
  static List<Car> _trending(List<Car> cars) {
    final list = [...cars]
      ..sort(
        (a, b) => (b.rating * 10 + b.trips / 10).compareTo(
          a.rating * 10 + a.trips / 10,
        ),
      );
    return list.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    final place = app.effectiveSearchPlace;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _nearby;
        },
        child: FutureBuilder<List<Car>>(
          future: _nearby,
          builder: (context, snap) {
            final cars = snap.data;
            final chosen = cars == null ? const <Car>[] : _chosen(app, cars);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              children: [
                Row(
                  children: [
                    Avatar(user?.name ?? '', size: 52),
                    const Spacer(),
                    if (app.backend.isDemo) ...[
                      const Pill(
                        'DEMO',
                        color: AppColors.primarySoft,
                        textColor: AppColors.primaryLight,
                        dot: false,
                      ),
                      const SizedBox(width: 10),
                    ],
                    CircleIconButton(
                      icon: Icons.search_rounded,
                      tooltip: context.tr('search_cars'),
                      size: 52,
                      onTap: _search,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('hello_name', {'name': user?.firstName ?? ''}),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('home_tagline'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),
                _SearchCard(
                  place: place.name,
                  start: app.searchStart,
                  end: app.searchEnd,
                  onPlace: _pickPlace,
                  onDates: _pickDates,
                  onSearch: _search,
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
                if (cars == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cars.isEmpty) ...[
                  const SizedBox(height: 16),
                  CardBox(child: Text(context.tr('no_cars_found'))),
                ] else ...[
                  SectionHeader(
                    context.tr('brands'),
                    action: context.tr('see_all'),
                    onAction: _search,
                  ),
                  BrandFilterRow(
                    makes: makesOf(cars),
                    selected: _brand,
                    onSelect: (m) => setState(() => _brand = m),
                  ),
                  SectionHeader(
                    context.tr('top_trends'),
                    action: context.tr('see_all'),
                    onAction: _search,
                  ),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _trending(cars).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) {
                        final c = _trending(cars)[i];
                        return TrendCard(car: c, onTap: () => _open(c));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 28, 0, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('choose_car'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CircleIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: context.tr('filters'),
                          size: 44,
                          onTap: _search,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip(null, context.tr('all_cars'), Icons.apps_rounded),
                        _chip(
                          _favorites,
                          context.tr('favorites'),
                          Icons.favorite_rounded,
                        ),
                        for (final c in Pricing.categories)
                          _chip(
                            c.id,
                            context.tr(c.nameKey),
                            categoryIcon(c.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (chosen.isEmpty)
                    CardBox(
                      child: Text(
                        context.tr(
                          _category == _favorites
                              ? 'no_favorites'
                              : 'no_cars_found',
                        ),
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ),
                  for (final c in chosen.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ChooseCarCard(
                        car: c,
                        distanceLabel: distanceLabel(place.point, c),
                        onTap: () => _open(c),
                      ),
                    ),
                  if (chosen.length > 8)
                    OutlinedButton(
                      onPressed: _search,
                      child: Text(
                        context.tr('see_all_n', {'n': '${chosen.length}'}),
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

  static const _favorites = '__favorites';

  Widget _chip(String? id, String label, IconData icon) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? Colors.white : AppColors.inkSoft,
        ),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
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

/// "Where / when" card with a red search button.
class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.place,
    required this.start,
    required this.end,
    required this.onPlace,
    required this.onDates,
    required this.onSearch,
  });

  final String place;
  final DateTime start;
  final DateTime end;
  final VoidCallback onPlace;
  final VoidCallback onDates;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 28,
      grouped: true,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _row(Icons.place_outlined, context.tr('where'), place, onPlace),
                const Divider(indent: 56, height: 1),
                _row(
                  Icons.calendar_month_outlined,
                  '${context.tr('pickup')} → ${context.tr('return')} · '
                      '${context.tr('n_days', {'n': '${rentalDays(start, end)}'})}',
                  '${context.day(start)} – ${context.day(end)}',
                  onDates,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: context.tr('search_cars'),
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSearch,
                  child: Ink(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: redDroplet,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x26000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.glassEdge),
                ),
                child: Icon(icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.applied, required this.onApply});

  final bool applied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 26,
      tint: AppColors.primary,
      grouped: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('limited_offer').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('promo_title', {'p': '${AppConfig.promoPercent}'}),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: applied ? const Color(0x33FFFFFF) : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: applied ? null : onApply,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
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
                        fontSize: 13,
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
          ),
        ],
      ),
    );
  }
}
