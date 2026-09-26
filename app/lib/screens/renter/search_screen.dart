import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/rental_widgets.dart';
import '../common/where_to_sheet.dart';
import 'car_detail_screen.dart';
import 'home_tab.dart' show distanceLabel;

/// Available cars for the chosen place and dates, as a list or on a map.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Sort { distance, priceLow, priceHigh, rating }

class _SearchScreenState extends State<SearchScreen> {
  late String? _category = widget.initialCategory;
  bool _showMap = false;
  bool _automaticOnly = false;
  String? _brand;
  List<String> _makes = const [];
  _Sort _sort = _Sort.distance;
  Future<List<Car>>? _results;
  Car? _selected;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final app = context.read<AppState>();
    _selected = null;
    _results = app.backend.searchCars(
      near: app.effectiveSearchPlace.point,
      start: app.searchStart,
      end: app.searchEnd,
      categoryId: _category,
    );
  }

  List<Car> _filtered(List<Car> cars) {
    _makes = makesOf(cars);
    final list = cars
        .where(
          (c) =>
              (!_automaticOnly || c.transmission == Transmission.automatic) &&
              (_brand == null || isMake(c, _brand!)),
        )
        .toList();
    switch (_sort) {
      case _Sort.priceLow:
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case _Sort.priceHigh:
        list.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _Sort.distance:
        break; // Server returns nearest first.
    }
    return list;
  }

  Future<void> _editPlace() async {
    final place = await showWhereTo(context, titleKey: 'where_need_car');
    if (place == null || !mounted) return;
    context.read<AppState>().setSearch(place: place);
    setState(_load);
  }

  Future<void> _editDates() async {
    final app = context.read<AppState>();
    final r = await pickRentalDates(
      context,
      start: app.searchStart,
      end: app.searchEnd,
    );
    if (r == null || !mounted) return;
    app.setSearch(start: r.$1, end: r.$2);
    setState(_load);
  }

  void _open(Car car) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => CarDetailScreen(car: car)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Glass(
                      radius: 24,
                      shadow: false,
                      onTap: _editPlace,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.effectiveSearchPlace.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${context.dayTime(app.searchStart)} → ${context.dayTime(app.searchEnd)}',
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.calendar_month_outlined,
                    tooltip: context.tr('choose_dates'),
                    onTap: _editDates,
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: _showMap
                        ? Icons.view_list_rounded
                        : Icons.map_outlined,
                    tooltip: context.tr(_showMap ? 'list_view' : 'map_view'),
                    color: _showMap ? AppColors.primary : null,
                    onTap: () => setState(() => _showMap = !_showMap),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip(context.tr('all_cars'), _category == null, () {
                setState(() {
                  _category = null;
                  _load();
                });
              }),
              for (final c in Pricing.categories)
                _chip(context.tr(c.nameKey), _category == c.id, () {
                  setState(() {
                    _category = c.id;
                    _load();
                  });
                }),
              _chip(
                context.tr('automatic'),
                _automaticOnly,
                () => setState(() => _automaticOnly = !_automaticOnly),
              ),
              PopupMenuButton<_Sort>(
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (context) => [
                  for (final s in _Sort.values)
                    PopupMenuItem(
                      value: s,
                      child: Text(context.tr('sort_${s.name}')),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort_rounded, size: 16),
                  label: Text(context.tr('sort_${_sort.name}')),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Car>>(
            future: _results,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(context.trError(errorCode(snap.error!))),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cars = _filtered(snap.data!);
              return _showMap ? _mapView(cars) : _listView(cars);
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _listView(List<Car> cars) {
    final place = context.read<AppState>().effectiveSearchPlace.point;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (_makes.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: BrandFilterRow(
              makes: _makes,
              selected: _brand,
              onSelect: (m) => setState(() => _brand = m),
            ),
          ),
        if (cars.isEmpty) _empty(),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            context.tr('n_cars_available', {'n': '${cars.length}'}),
            style: const TextStyle(color: AppColors.inkSoft),
          ),
        ),
        for (final c in cars)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChooseCarCard(
              car: c,
              distanceLabel: distanceLabel(place, c),
              onTap: () => _open(c),
            ),
          ),
      ],
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.car_rental_rounded,
            size: 56,
            color: AppColors.inkFaint,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('no_cars_found'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _editDates,
            child: Text(context.tr('change_dates')),
          ),
        ],
      ),
    ),
  );

  Widget _mapView(List<Car> cars) {
    final app = context.read<AppState>();
    final place = app.effectiveSearchPlace.point;
    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            controller: _map,
            center: place,
            zoom: 12.5,
            onReady: () {
              if (cars.isNotEmpty) {
                fitPoints(_map, [
                  place,
                  ...cars.map((c) => c.location.point),
                ], padding: const EdgeInsets.fromLTRB(60, 60, 60, 220));
              }
            },
            children: [
              MarkerLayer(markers: [pinMarker(place, pickup: true)]),
              MarkerLayer(
                markers: [
                  for (final c in cars)
                    priceMarker(
                      c,
                      label: money(c.pricePerDay),
                      selected: _selected?.id == c.id,
                      onTap: () => setState(() => _selected = c),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black,
                borderRadius: BorderRadius.circular(18),
                child: CarListingCard(
                  car: _selected!,
                  distanceLabel: distanceLabel(place, _selected!),
                  onTap: () => _open(_selected!),
                ),
              ),
            ),
          )
        else if (cars.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: CardBox(child: Text(context.tr('no_cars_found'))),
          ),
      ],
    );
  }
}
