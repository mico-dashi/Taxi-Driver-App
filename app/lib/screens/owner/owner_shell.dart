import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/design.dart';
import '../common/chats_tab.dart';
import '../common/profile_widgets.dart';
import 'my_cars_tab.dart';
import 'requests_tab.dart';

/// "Kam makinë për qira": the owner's side of the app.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          RequestsTab(
            key: ValueKey('requests-$_tab'),
            onAddCar: () => setState(() => _tab = 1),
          ),
          const MyCarsTab(),
          ChatsTab(key: ValueKey('chats-$_tab'), asOwner: true),
          EarningsTab(key: ValueKey('earnings-$_tab')),
          const OwnerAccountTab(),
        ],
      ),
      bottomNavigationBar: PillNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          NavItem(
            Icons.inbox_outlined,
            Icons.inbox_rounded,
            context.tr('tab_requests'),
          ),
          NavItem(
            Icons.directions_car_outlined,
            Icons.directions_car_rounded,
            context.tr('tab_my_cars'),
          ),
          NavItem(
            Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded,
            context.tr('tab_chat'),
          ),
          NavItem(
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet_rounded,
            context.tr('tab_earnings'),
          ),
          NavItem(
            Icons.person_outline_rounded,
            Icons.person_rounded,
            context.tr('tab_account'),
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
  late Future<OwnerEarnings> _data = context
      .read<AppState>()
      .backend
      .earnings();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _data = context.read<AppState>().backend.earnings();
          });
          await _data;
        },
        child: FutureBuilder<OwnerEarnings>(
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
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8E0310), AppColors.primary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('this_month'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(e.thisMonth),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _stat(
                              context.tr('rentals'),
                              '${e.rentalsThisMonth}',
                            ),
                            _stat(
                              context.tr('days_rented'),
                              '${e.bookedDaysThisMonth}',
                            ),
                            _stat(
                              context.tr('avg_per_day'),
                              e.bookedDaysThisMonth == 0
                                  ? '—'
                                  : money(e.thisMonth ~/ e.bookedDaysThisMonth),
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
                          child: Text(
                            context.tr('all_time'),
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                        Text(
                          money(e.allTime),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionLabel(context.tr('completed_rentals')),
                  if (e.recent.isEmpty)
                    Text(
                      context.tr('no_completed_rentals'),
                      style: const TextStyle(color: AppColors.inkSoft),
                    )
                  else
                    for (final b in e.recent)
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
                                      '${b.car.title} · ${b.renterName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      context.dayRange(b.start, b.end),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                money(Pricing.quoteFor(b).total),
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

class OwnerAccountTab extends StatelessWidget {
  const OwnerAccountTab({super.key});

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
          SectionLabel(context.tr('documents')),
          for (final doc in const [
            'doc_registration',
            'doc_insurance',
            'doc_id',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ProfileTile(
                icon: Icons.description_outlined,
                title: context.tr(doc),
                subtitle: context.tr('doc_send_office'),
              ),
            ),
          SectionLabel(context.tr('settings')),
          const SettingsTiles(),
          const SizedBox(height: 8),
          ProfileTile(
            icon: Icons.search_rounded,
            title: context.tr('switch_to_renter'),
            onTap: () => switchRole(context, UserRole.renter),
          ),
        ],
      ),
    );
  }
}
