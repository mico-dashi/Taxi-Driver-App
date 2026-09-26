import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// First-time setup: name + "I want to ride" / "I drive a taxi".
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  UserRole _role = UserRole.renter;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      showInfo(context, context.tr('enter_name'));
      return;
    }
    setState(() => _loading = true);
    final app = context.read<AppState>();
    try {
      app.setUser(await app.backend.saveProfile(name: name, role: _role));
      if (mounted) goHome(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(
              context.tr('setup_title'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('setup_subtitle'),
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: context.tr('full_name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            SectionLabel(context.tr('how_use_app')),
            _RoleCard(
              icon: Icons.search_rounded,
              title: context.tr('role_renter'),
              subtitle: context.tr('role_renter_desc'),
              selected: _role == UserRole.renter,
              onTap: () => setState(() => _role = UserRole.renter),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.car_rental_rounded,
              title: context.tr('role_owner'),
              subtitle: context.tr('role_owner_desc'),
              selected: _role == UserRole.owner,
              onTap: () => setState(() => _role = UserRole.owner),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(context.tr('get_started')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.ink : AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}
