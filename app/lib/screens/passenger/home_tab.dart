import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/routing_service.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../booking/booking_flow_screen.dart';
import '../booking/where_to_sheet.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _category = 'standard';
  List<Driver> _drivers = [];
  StreamSubscription<List<Driver>>? _sub;
  LatLng? _watching;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final here = context.watch<AppState>().here;
    if (_watching != here) {
      _watching = here;
      _sub?.cancel();
      _sub = context.read<AppState>().backend.watchNearbyDrivers(here).listen((
        d,
      ) {
        if (mounted) setState(() => _drivers = d);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('good_morning');
    if (h < 18) return context.tr('good_afternoon');
    return context.tr('good_evening');
  }

  Future<void> _startBooking({String? categoryId, Place? destination}) async {
    final app = context.read<AppState>();
    final dest = destination ?? await showWhereTo(context);
    if (dest == null || !mounted) return;
    app.addRecent(dest);
    final pickup =
        app.herePlace ?? Place(context.tr('current_location'), '', app.here);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingFlowScreen(
          pickup: pickup,
          destination: dest,
          initialCategory: categoryId ?? _category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    final visible = _drivers
        .where((d) => d.vehicle.categoryId == _category)
        .toList();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: app.refreshLocation,
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              app.herePlace?.name ?? context.tr('locating'),
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
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _startBooking,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('where_to_go'),
                          style: const TextStyle(
                            color: AppColors.inkFaint,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            if (app.homePlace != null || app.workPlace != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (app.homePlace != null)
                    _ShortcutChip(
                      icon: Icons.home_rounded,
                      label: context.tr('home_place'),
                      onTap: () => _startBooking(destination: app.homePlace),
                    ),
                  if (app.workPlace != null)
                    _ShortcutChip(
                      icon: Icons.work_rounded,
                      label: context.tr('work_place'),
                      onTap: () => _startBooking(destination: app.workPlace),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: Pricing.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final c = Pricing.categories[i];
                  final nearest = _drivers
                      .where((d) => d.vehicle.categoryId == c.id)
                      .map(
                        (d) => RoutingService.etaMinutes(d.location, app.here),
                      );
                  final eta = nearest.isEmpty
                      ? null
                      : nearest.reduce((a, b) => a < b ? a : b);
                  return _CategoryCard(
                    category: c,
                    eta: eta,
                    onTap: () => _startBooking(categoryId: c.id),
                  );
                },
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
              context.tr('available_cars'),
              trailing: _CategoryTabs(
                value: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
            if (visible.isEmpty)
              CardBox(
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr('no_cars_nearby'))),
                  ],
                ),
              )
            else
              for (final d in visible.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverCard(
                    driver: d,
                    eta: RoutingService.etaMinutes(d.location, app.here),
                    onBook: () =>
                        _startBooking(categoryId: d.vehicle.categoryId),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.eta,
    required this.onTap,
  });

  final VehicleCategory category;
  final int? eta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luxury = category.id == 'luxury';
    return SizedBox(
      width: 170,
      child: CardBox(
        onTap: onTap,
        color: luxury ? AppColors.primarySoft : const Color(0xFFEFF4FF),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(category.id), size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr(category.nameKey),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('from_per_km', {'p': money(category.perKm)}),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  eta == null ? '—' : minutes(eta!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
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
    );
  }
}

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
          const Icon(Icons.local_taxi_rounded, size: 84, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in Pricing.categories)
          GestureDetector(
            onTap: () => onChanged(c.id),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: value == c.id
                    ? const Color(0xFFE3ECFF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr(c.nameKey),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value == c.id
                      ? AppColors.verified
                      : AppColors.inkFaint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.eta,
    required this.onBook,
  });

  final Driver driver;
  final int eta;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final c = Pricing.byId(driver.vehicle.categoryId);
    return CardBox(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.vehicle.make.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    Text(
                      driver.vehicle.model,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        Text(
                          ' ${minutes(eta)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.airline_seat_recline_normal_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        Flexible(
                          child: Text(
                            ' ${context.tr('n_seats', {'n': '${driver.vehicle.seats}'})}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
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
                  CarBadge(categoryId: driver.vehicle.categoryId, size: 64),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: money(c.perKm),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const TextSpan(
                          text: '/km',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Avatar(driver.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Rating(driver.rating, trips: driver.trips),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text('${context.tr('book')} →'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
