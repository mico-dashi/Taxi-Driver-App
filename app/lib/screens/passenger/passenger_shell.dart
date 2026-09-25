import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../ride/ride_screen.dart';
import 'bookings_tab.dart';
import 'chats_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';

class PassengerShell extends StatefulWidget {
  const PassengerShell({super.key});

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _resumeActiveRide();
  }

  /// If the app was closed during a ride, jump straight back to it.
  Future<void> _resumeActiveRide() async {
    try {
      final ride = await context.read<AppState>().backend.activeRide();
      if (ride == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RideScreen(initial: ride)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeTab(),
      BookingsTab(key: ValueKey('bookings-$_tab')),
      const ChatsTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.tr('tab_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: context.tr('tab_bookings'),
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
