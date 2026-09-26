import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import 'payment_widgets.dart';
import 'where_to_sheet.dart';

class RenterProfileTab extends StatelessWidget {
  const RenterProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () => editName(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          SectionLabel(context.tr('saved_places')),
          _SavedPlaceTile(home: true, place: app.homePlace),
          const SizedBox(height: 8),
          _SavedPlaceTile(home: false, place: app.workPlace),
          SectionLabel(context.tr('payment_methods')),
          const PaymentMethodList(manage: true),
          SectionLabel(context.tr('promo_code')),
          const _PromoField(),
          SectionLabel(context.tr('settings')),
          const SettingsTiles(),
          const SizedBox(height: 8),
          ProfileTile(
            icon: Icons.car_rental_rounded,
            title: context.tr('become_owner'),
            subtitle: context.tr('become_owner_desc'),
            onTap: () => switchRole(context, UserRole.owner),
          ),
        ],
      ),
    );
  }
}

/// Language, safety, support, legal and sign out (shared with driver mode).
class SettingsTiles extends StatelessWidget {
  const SettingsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Column(
      children: [
        ProfileTile(
          icon: Icons.translate_rounded,
          title: context.tr('language'),
          trailing: const LanguageToggle(),
        ),
        const SizedBox(height: 8),
        ProfileTile(
          icon: Icons.shield_outlined,
          title: context.tr('safety'),
          onTap: () => showSafetySheet(context),
        ),
        const SizedBox(height: 8),
        ProfileTile(
          icon: Icons.support_agent_rounded,
          title: context.tr('support'),
          subtitle: AppConfig.supportEmail,
          onTap: () =>
              launchUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail)),
        ),
        const SizedBox(height: 8),
        ProfileTile(
          icon: Icons.description_outlined,
          title: context.tr('terms_privacy'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: AppConfig.brandName,
            applicationVersion: '1.0.0',
            applicationLegalese: context.tr('legal_text'),
          ),
        ),
        const SizedBox(height: 8),
        ProfileTile(
          icon: Icons.logout_rounded,
          title: context.tr('sign_out'),
          danger: true,
          onTap: () async {
            await app.signOut();
            if (context.mounted) goHome(context);
          },
        ),
      ],
    );
  }
}

Future<void> switchRole(BuildContext context, UserRole role) async {
  final app = context.read<AppState>();
  final user = app.user;
  if (user == null) return;
  try {
    app.setUser(await app.backend.saveProfile(name: user.name, role: role));
    if (context.mounted) goHome(context);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> editName(BuildContext context) async {
  final app = context.read<AppState>();
  final ctrl = TextEditingController(text: app.user?.name);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('full_name')),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.tr('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(ctx.tr('save')),
        ),
      ],
    ),
  );
  if (name == null || name.length < 2 || app.user == null) return;
  try {
    app.setUser(
      await app.backend.saveProfile(name: name, role: app.user!.role),
    );
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class _SavedPlaceTile extends StatelessWidget {
  const _SavedPlaceTile({required this.home, required this.place});

  final bool home;
  final Place? place;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return ProfileTile(
      icon: home ? Icons.home_outlined : Icons.work_outline_rounded,
      title: context.tr(home ? 'home_place' : 'work_place'),
      subtitle: place?.name ?? context.tr('tap_to_set'),
      trailing: place == null
          ? null
          : IconButton(
              onPressed: () => app.setSavedPlace(home: home, place: null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
      onTap: () async {
        final p = await showWhereTo(
          context,
          titleKey: home ? 'set_home' : 'set_work',
        );
        if (p != null) app.setSavedPlace(home: home, place: p);
      },
    );
  }
}

class _PromoField extends StatefulWidget {
  const _PromoField();

  @override
  State<_PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends State<_PromoField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.promoCode != null) {
      return ProfileTile(
        icon: Icons.local_offer_outlined,
        title: app.promoCode!,
        subtitle: context.tr('promo_applied', {'p': '${app.promoPercent}'}),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: context.tr('enter_code')),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(90, 52)),
          onPressed: () async {
            final pct = await app.applyPromo(_ctrl.text);
            if (!context.mounted) return;
            showInfo(
              context,
              pct > 0
                  ? context.tr('promo_applied', {'p': '$pct'})
                  : context.tr('promo_invalid'),
            );
          },
          child: Text(context.tr('apply')),
        ),
      ],
    );
  }
}

/// Settings-style row (also used by the driver account screen).
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

/// Emergency numbers for Albania.
Future<void> showSafetySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        Widget tile(IconData icon, String label, String number, Color color) =>
            ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(number),
              trailing: const Icon(Icons.call_rounded),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ctx.tr('safety'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                tile(
                  Icons.sos_rounded,
                  ctx.tr('emergency'),
                  AppConfig.emergencyNumber,
                  AppColors.danger,
                ),
                tile(
                  Icons.local_police_outlined,
                  ctx.tr('police'),
                  AppConfig.policeNumber,
                  AppColors.verified,
                ),
                tile(
                  Icons.local_hospital_outlined,
                  ctx.tr('ambulance'),
                  AppConfig.ambulanceNumber,
                  AppColors.success,
                ),
                tile(
                  Icons.support_agent_rounded,
                  ctx.tr('support'),
                  AppConfig.supportPhone,
                  AppColors.ink,
                ),
              ],
            ),
          ),
        );
      },
    );
