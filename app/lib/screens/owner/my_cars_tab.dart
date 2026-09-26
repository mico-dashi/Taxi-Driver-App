import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/rental_widgets.dart';
import 'car_form_screen.dart';

class MyCarsTab extends StatefulWidget {
  const MyCarsTab({super.key});

  @override
  State<MyCarsTab> createState() => _MyCarsTabState();
}

class _MyCarsTabState extends State<MyCarsTab> {
  late Future<List<Car>> _cars = context.read<AppState>().backend.myCars();

  Future<void> _reload() async {
    setState(() {
      _cars = context.read<AppState>().backend.myCars();
    });
    await _cars;
  }

  Future<void> _edit([Car? car]) async {
    final saved = await Navigator.of(
      context,
    ).push<Car>(MaterialPageRoute(builder: (_) => CarFormScreen(initial: car)));
    if (saved != null && mounted) {
      showInfo(context, context.tr(car == null ? 'car_added' : 'car_saved'));
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = context.read<AppState>().backend.isDemo;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('add_car')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Car>>(
            future: _cars,
            builder: (context, snap) {
              final cars = snap.data ?? const <Car>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                children: [
                  Text(
                    context.tr('tab_my_cars'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('my_cars_desc'),
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                  if (!demo) ...[
                    const SizedBox(height: 12),
                    CardBox(
                      color: AppColors.primarySoft,
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined),
                          const SizedBox(width: 10),
                          Expanded(child: Text(context.tr('approval_note'))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!snap.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (cars.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.directions_car_outlined,
                            size: 56,
                            color: AppColors.inkFaint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('no_cars_body'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  for (final c in cars)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CardBox(
                        onTap: () => _edit(c),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CarBadge.of(c, size: 52),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${c.title} · ${c.year}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Plate(c.plate),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${money(c.pricePerDay)}${context.tr('per_day_short')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: AppColors.inkSoft,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    c.location.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                                Text(
                                  context.tr(c.listed ? 'listed' : 'hidden'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.listed
                                        ? AppColors.success
                                        : AppColors.inkFaint,
                                  ),
                                ),
                                Switch(
                                  value: c.listed,
                                  activeTrackColor: AppColors.success,
                                  onChanged: (v) async {
                                    await context
                                        .read<AppState>()
                                        .backend
                                        .setListed(c.id, v);
                                    _reload();
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${transmissionLabel(context, c.transmission)} · ${fuelLabel(context, c.fuel)} · ${context.tr('n_seats', {'n': '${c.seats}'})}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Rating(c.rating, trips: c.trips),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
