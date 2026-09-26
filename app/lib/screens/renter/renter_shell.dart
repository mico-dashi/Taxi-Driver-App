import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../widgets/design.dart';
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
      // The glass menu floats over the content.
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onOpenRentals: () => setState(() => _tab = 1)),
          RentalsTab(key: ValueKey('rentals-$_tab')),
          ChatsTab(key: ValueKey('chats-$_tab'), asOwner: false),
          const RenterProfileTab(),
        ],
      ),
      bottomNavigationBar: PillNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          NavItem(
            Icons.home_outlined,
            Icons.home_rounded,
            context.tr('tab_search'),
          ),
          NavItem(
            Icons.key_outlined,
            Icons.key_rounded,
            context.tr('tab_rentals'),
          ),
          NavItem(
            Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded,
            context.tr('tab_chat'),
          ),
          NavItem(
            Icons.person_outline_rounded,
            Icons.person_rounded,
            context.tr('tab_profile'),
          ),
        ],
      ),
    );
  }
}
