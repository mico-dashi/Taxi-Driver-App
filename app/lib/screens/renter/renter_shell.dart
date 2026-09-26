import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../common/chats_tab.dart';
import '../common/profile_widgets.dart';
import 'home_tab.dart';
import 'rentals_tab.dart';

/// "Gjej makinë me qira": the renter's side of the app.
class RenterShell extends StatefulWidget {
  const RenterShell({super.key});

  @override
  State<RenterShell> createState() => _RenterShellState();
}

class _RenterShellState extends State<RenterShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onOpenRentals: () => setState(() => _tab = 1)),
          RentalsTab(key: ValueKey('rentals-$_tab')),
          ChatsTab(key: ValueKey('chats-$_tab'), asOwner: false),
          const RenterProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.manage_search_rounded),
            label: context.tr('tab_search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.key_outlined),
            selectedIcon: const Icon(Icons.key_rounded),
            label: context.tr('tab_rentals'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: context.tr('tab_chat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: context.tr('tab_profile'),
          ),
        ],
      ),
    );
  }
}
