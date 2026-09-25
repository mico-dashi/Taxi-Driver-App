import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../services/routing_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../ride/finding_driver_screen.dart';
import 'payment_widgets.dart';
import 'where_to_sheet.dart';

/// Route → Payment → Car, exactly like the reference video.
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.pickup,
    required this.destination,
    this.initialCategory = 'standard',
  });

  final Place pickup;
  final Place destination;
  final String initialCategory;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  final _map = MapController();
  bool _mapReady = false;
  int _step = 0;
  late Place _pickup = widget.pickup;
  late Place _destination = widget.destination;
  RouteInfo? _route;
  late String _category = widget.initialCategory;
  int? _customFare;
  List<Driver> _drivers = [];
  StreamSubscription<List<Driver>>? _driversSub;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _driversSub = context
        .read<AppState>()
        .backend
        .watchNearbyDrivers(_pickup.point)
        .listen((d) {
          if (mounted) setState(() => _drivers = d);
        });
  }

  @override
  void dispose() {
    _driversSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() => _route = null);
    final route = await context.read<AppState>().routing.route(
      _pickup.point,
      _destination.point,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _customFare = null;
    });
    _fit();
  }

  void _fit() {
    if (_mapReady && _route != null) fitPoints(_map, _route!.points);
  }

  bool get _isAirport =>
      '${_pickup.name} ${_destination.name}'.toLowerCase().contains('aeroport');

  int _estimate(String categoryId) {
    final r = _route!;
    return Pricing.estimate(
      Pricing.byId(categoryId),
      r.distanceKm,
      r.durationMin,
      airport: _isAirport,
      discountPercent: context.read<AppState>().promoPercent,
    );
  }

  int get _fare => _customFare ?? _estimate(_category);

  Future<void> _change({required bool pickup}) async {
    final place = await showWhereTo(
      context,
      titleKey: pickup ? 'pickup_from' : 'where_to',
    );
    if (place == null) return;
    setState(() => pickup ? _pickup = place : _destination = place);
    _loadRoute();
  }

  void _swap() {
    setState(() {
      final p = _pickup;
      _pickup = _destination;
      _destination = p;
    });
    _loadRoute();
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  void _findDriver() {
    final app = context.read<AppState>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FindingDriverScreen(
          pickup: _pickup,
          destination: _destination,
          route: _route!,
          categoryId: _category,
          fare: _fare,
          payment: app.selectedPayment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _step == 0 ? Colors.transparent : AppColors.background,
        body: _step == 0
            ? _routeStep()
            : SafeArea(child: _step == 1 ? _paymentStep() : _carStep()),
      ),
    );
  }

  // ------------------------------------------------------------ step 1

  Widget _routeStep() {
    final route = _route;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: _pickup.point,
              onReady: () {
                _mapReady = true;
                _fit();
              },
              children: [
                if (route != null)
                  PolylineLayer(polylines: [routeLine(route.points)]),
                MarkerLayer(
                  markers: [
                    pinMarker(_pickup.point, pickup: true),
                    pinMarker(
                      _destination.point,
                      pickup: false,
                      label: _destination.name,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StepHeader(step: 0, onBack: _back),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircleIconButton(
                    icon: Icons.center_focus_strong_rounded,
                    onTap: _fit,
                  ),
                ),
                SheetCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _placeRow(
                                  icon: Icons.my_location_rounded,
                                  label: context.tr('pickup_current'),
                                  place: _pickup,
                                  onTap: () => _change(pickup: true),
                                ),
                                const Divider(height: 20, indent: 44),
                                _placeRow(
                                  icon: Icons.flag_outlined,
                                  label: context.tr('destination'),
                                  place: _destination,
                                  onTap: () => _change(pickup: false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleIconButton(
                            icon: Icons.swap_vert_rounded,
                            onTap: _swap,
                            size: 40,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _infoChip(
                              Icons.route_rounded,
                              route == null ? '…' : km(route.distanceKm),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _infoChip(
                              Icons.schedule_rounded,
                              route == null
                                  ? '…'
                                  : context.tr('min_drive', {
                                      'm': minutes(route.durationMin),
                                    }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: route == null
                            ? null
                            : () => setState(() => _step = 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(context.tr('continue_to_payment')),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeRow({
    required IconData icon,
    required String label,
    required Place place,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkFaint,
                  ),
                ),
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tripSummary() {
    final r = _route!;
    return RouteSummary(
      pickup: _pickup.name,
      destination: _destination.name,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            km(r.distanceKm),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '~${minutes(r.durationMin)}',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ step 2

  Widget _paymentStep() {
    final app = context.watch<AppState>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: StepHeader(step: 1, onBack: _back),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Text(
                context.tr('how_pay'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('charged_after'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              _tripSummary(),
              const PaymentMethodList(),
            ],
          ),
        ),
        _bottomBar(
          leading: PaymentChip(
            method: app.selectedPayment,
            prefix: context.tr('paying_with'),
          ),
          button: ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(minimumSize: const Size(140, 52)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('continue')),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 3

  Widget _carStep() {
    final app = context.watch<AppState>();
    final nearbyInCategory = _drivers
        .where((d) => d.vehicle.categoryId == _category)
        .toList();
    final estimate = _estimate(_category);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: StepHeader(step: 2, onBack: _back),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Text(
                context.tr('choose_car'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('fares_note'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              _tripSummary(),
              SectionLabel(
                context.tr('car_types'),
                trailing: Pill(
                  context.tr('n_nearby', {'n': '${nearbyInCategory.length}'}),
                ),
              ),
              for (final c in Pricing.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CategoryOption(
                    category: c,
                    fare: _estimate(c.id),
                    drivers: _drivers
                        .where((d) => d.vehicle.categoryId == c.id)
                        .toList(),
                    pickup: _pickup,
                    selected: c.id == _category,
                    onTap: () => setState(() {
                      _category = c.id;
                      _customFare = null;
                    }),
                  ),
                ),
              const SizedBox(height: 6),
              _FareAdjuster(
                fare: _fare,
                estimate: estimate,
                onChanged: (v) => setState(() => _customFare = v),
              ),
              if (app.promoPercent > 0) ...[
                const SizedBox(height: 10),
                Pill(context.tr('promo_applied', {'p': '${app.promoPercent}'})),
              ],
              if (Pricing.isNight(DateTime.now())) ...[
                const SizedBox(height: 10),
                Text(
                  context.tr('night_tariff'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        _bottomBar(
          leading: PaymentChip(
            method: app.selectedPayment,
            prefix: context.tr('pay_with'),
            onTap: () => setState(() => _step = 1),
          ),
          button: ElevatedButton(
            onPressed: _findDriver,
            style: ElevatedButton.styleFrom(minimumSize: const Size(170, 52)),
            child: Text('${context.tr('find_driver')} · ${money(_fare)}'),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar({required Widget leading, required Widget button}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: leading),
          const SizedBox(width: 12),
          button,
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.fare,
    required this.drivers,
    required this.pickup,
    required this.selected,
    required this.onTap,
  });

  final VehicleCategory category;
  final int fare;
  final List<Driver> drivers;
  final Place pickup;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final etas =
        drivers
            .map((d) => RoutingService.etaMinutes(d.location, pickup.point))
            .toList()
          ..sort();
    final models = drivers
        .map((d) => d.vehicle.title)
        .toSet()
        .take(2)
        .join(', ');
    return CardBox(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CarBadge(categoryId: category.id, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(category.nameKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (models.isNotEmpty)
                  Text(
                    models,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.inkSoft,
                    ),
                    Text(
                      ' ${etas.isEmpty ? '—' : minutes(etas.first)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: AppColors.inkSoft,
                    ),
                    Text(
                      ' ${category.seats}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(fare),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                '${money(category.perKm)}/km',
                style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// inDrive-style: passengers can offer a bit more to get a driver faster,
/// or slightly less (never below 80% of the estimate).
class _FareAdjuster extends StatelessWidget {
  const _FareAdjuster({
    required this.fare,
    required this.estimate,
    required this.onChanged,
  });

  final int fare;
  final int estimate;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final min = Pricing.roundFare(estimate * 0.8);
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('your_offer'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                Text(
                  money(fare),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: fare - 50 >= min ? () => onChanged(fare - 50) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => onChanged(fare + 50),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
