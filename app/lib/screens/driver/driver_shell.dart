import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/supabase_backend.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../passenger/profile_tab.dart';
import 'drive_tab.dart';
import 'vehicle_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _ensureVehicle();
  }

  /// A driver must register a vehicle before going online.
  Future<void> _ensureVehicle() async {
    final vehicle = await context.read<AppState>().backend.myVehicle();
    if (vehicle != null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<Vehicle>(
        builder: (_) => const VehicleScreen(required: true),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const DriveTab(),
          EarningsTab(key: ValueKey('earnings-$_tab')),
          DriverAccountTab(key: ValueKey('account-$_tab')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_taxi_outlined),
            selectedIcon: const Icon(Icons.local_taxi_rounded),
            label: context.tr('tab_drive'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: context.tr('tab_earnings'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: context.tr('tab_account'),
          ),
        ],
      ),
    );
  }
}

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  late Future<DriverEarnings> _data = context
      .read<AppState>()
      .backend
      .earnings();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _data = context.read<AppState>().backend.earnings());
          await _data;
        },
        child: FutureBuilder<DriverEarnings>(
          future: _data,
          builder: (context, snap) {
            final e = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  context.tr('tab_earnings'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (snap.hasError)
                  Text(context.trError(errorCode(snap.error!)))
                else if (e == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('today'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(e.today),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _stat(context.tr('trips'), '${e.tripsToday}'),
                            if (e.onlineHoursToday > 0)
                              _stat(
                                context.tr('online_hours'),
                                e.onlineHoursToday.toStringAsFixed(1),
                              ),
                            _stat(
                              context.tr('avg_trip'),
                              e.tripsToday == 0
                                  ? '—'
                                  : money(e.today ~/ e.tripsToday),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardBox(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('last_7_days'),
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              Text(
                                money(e.week),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          context.tr('n_trips', {'n': '${e.tripsWeek}'}),
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardBox(
                    color: AppColors.successSoft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(context.tr('zero_commission'))),
                      ],
                    ),
                  ),
                  SectionLabel(context.tr('recent_trips')),
                  if (e.recent.isEmpty)
                    Text(
                      context.tr('no_trips_yet'),
                      style: const TextStyle(color: AppColors.inkSoft),
                    )
                  else
                    for (final r in e.recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardBox(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.request.destination.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${hhmm(r.createdAt)} · ${km(r.request.route.distanceKm)} · ${paymentTypeLabel(context, r.request.payment)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                money(r.price + r.tip),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ),
  );
}

class DriverAccountTab extends StatefulWidget {
  const DriverAccountTab({super.key});

  @override
  State<DriverAccountTab> createState() => _DriverAccountTabState();
}

class _DriverAccountTabState extends State<DriverAccountTab> {
  Vehicle? _vehicle;
  bool? _approved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final backend = context.read<AppState>().backend;
    final v = await backend.myVehicle();
    final approved = backend is SupabaseBackend
        ? await backend.vehicleApproved()
        : true;
    if (mounted) {
      setState(() {
        _vehicle = v;
        _approved = approved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Avatar(user?.name ?? '', size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user?.phone ?? '',
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 4),
                    Rating(user?.rating ?? 5),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => editName(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          SectionLabel(context.tr('your_vehicle')),
          CardBox(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<Vehicle>(
                  builder: (_) => VehicleScreen(initial: _vehicle),
                ),
              );
              _load();
            },
            child: Row(
              children: [
                CarBadge(
                  categoryId: _vehicle?.categoryId ?? 'standard',
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vehicle?.title ?? context.tr('add_vehicle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_vehicle != null) ...[
                        const SizedBox(height: 4),
                        Plate(_vehicle!.plate),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          if (_approved == false) ...[
            const SizedBox(height: 10),
            CardBox(
              color: AppColors.primarySoft,
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('pending_approval'))),
                ],
              ),
            ),
          ],
          SectionLabel(context.tr('documents')),
          for (final doc in const [
            'doc_license',
            'doc_registration',
            'doc_taxi_permit',
            'doc_insurance',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ProfileTile(
                icon: Icons.description_outlined,
                title: context.tr(doc),
                subtitle: context.tr(
                  _approved == true ? 'doc_verified' : 'doc_send_office',
                ),
                trailing: Icon(
                  _approved == true
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: _approved == true
                      ? AppColors.success
                      : AppColors.inkFaint,
                ),
              ),
            ),
          SectionLabel(context.tr('settings')),
          const SettingsTiles(),
          const SizedBox(height: 8),
          ProfileTile(
            icon: Icons.hail_rounded,
            title: context.tr('switch_to_passenger'),
            onTap: () => switchRole(context, UserRole.passenger),
          ),
        ],
      ),
    );
  }
}
