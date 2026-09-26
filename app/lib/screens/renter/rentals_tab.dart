import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/rental_widgets.dart';
import '../common/booking_screen.dart';

/// The renter's bookings: waiting for an answer, upcoming/active, past.
class RentalsTab extends StatefulWidget {
  const RentalsTab({super.key});

  @override
  State<RentalsTab> createState() => _RentalsTabState();
}

class _RentalsTabState extends State<RentalsTab> {
  late Future<List<Booking>> _data = context
      .read<AppState>()
      .backend
      .myRentals();

  Future<void> _refresh() async {
    setState(() {
      _data = context.read<AppState>().backend.myRentals();
    });
    await _data;
  }

  Future<void> _open(Booking b) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => BookingScreen(initial: b)));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Booking>>(
          future: _data,
          builder: (context, snap) {
            final all = snap.data ?? const <Booking>[];
            final open = all.where((b) => b.isOpen).toList();
            final current = all.where((b) => b.isUpcomingOrActive).toList();
            final past = all.where((b) => b.isFinished).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  context.tr('tab_rentals'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!snap.hasData)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.key_outlined,
                          size: 56,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('no_rentals'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ..._section(context.tr('current_rentals'), current),
                ..._section(context.tr('waiting_answer'), open),
                ..._section(context.tr('past_rentals'), past),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<Booking> list) => [
    if (list.isNotEmpty) SectionLabel(title),
    for (final b in list)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BookingTile(booking: b, asOwner: false, onTap: () => _open(b)),
      ),
  ];
}
