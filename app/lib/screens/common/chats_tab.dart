import 'dart:async';

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

/// Conversations for bookings that are open, upcoming or running, plus
/// customer support.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key, required this.asOwner});

  final bool asOwner;

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  List<Booking>? _bookings;
  StreamSubscription<List<Booking>>? _sub;

  @override
  void initState() {
    super.initState();
    final backend = context.read<AppState>().backend;
    if (widget.asOwner) {
      _sub = backend.watchOwnerBookings().listen((b) {
        if (mounted) setState(() => _bookings = b);
      });
    } else {
      backend.myRentals().then((b) {
        if (mounted) setState(() => _bookings = b);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = (_bookings ?? const <Booking>[])
        .where((b) => !b.isFinished || b.status == BookingStatus.completed)
        .take(20)
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            context.tr('tab_chat'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          if (_bookings != null && list.isEmpty)
            Padding(
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
                    context.tr(widget.asOwner ? 'no_chats_owner' : 'no_chats'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          if (list.isNotEmpty) SectionLabel(context.tr('conversations')),
          for (final b in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardBox(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      bookingId: b.id,
                      peerName: widget.asOwner ? b.renterName : b.car.ownerName,
                      peerPhone: b.isUpcomingOrActive
                          ? (widget.asOwner ? b.renterPhone : b.car.ownerPhone)
                          : '',
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Avatar(widget.asOwner ? b.renterName : b.car.ownerName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.asOwner ? b.renterName : b.car.ownerName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${b.car.title} · ${context.dayRange(b.start, b.end)}',
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
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
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
    );
  }
}
