import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../chat/chat_screen.dart';

/// Chat with the current driver, plus customer support.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  late Future<Ride?> _active = context.read<AppState>().backend.activeRide();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(
            () => _active = context.read<AppState>().backend.activeRide(),
          );
          await _active;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              context.tr('tab_chat'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            FutureBuilder<Ride?>(
              future: _active,
              builder: (context, snap) {
                final ride = snap.data;
                if (ride == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('no_chats'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(context.tr('your_driver')),
                    CardBox(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            rideId: ride.id,
                            peerName: ride.driver.name,
                            peerPhone: ride.driver.phone,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Avatar(ride.driver.name),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ride.driver.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${ride.driver.vehicle.title} · ${ride.driver.vehicle.plate}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            SectionLabel(context.tr('support')),
            CardBox(
              onTap: () => launchUrl(
                Uri.parse(
                  'https://wa.me/${AppConfig.supportPhone.replaceAll('+', '')}',
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('support_team', {
                            'brand': AppConfig.brandName,
                          }),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.tr('support_desc'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
