import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class TripCompleteScreen extends StatefulWidget {
  const TripCompleteScreen({super.key, required this.ride});

  final Ride ride;

  @override
  State<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends State<TripCompleteScreen> {
  int _stars = 5;
  int _tip = 0;
  final _comment = TextEditingController();
  bool _sending = false;

  static const _tips = [0, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    context.read<AppState>().consumePromo();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await context.read<AppState>().backend.rateRide(
        widget.ride.id,
        stars: _stars,
        tip: _tip,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      showInfo(context, context.tr('thanks_rating'));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.successSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: AppColors.success,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  context.tr('you_arrived'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  r.request.destination.name,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
              const SizedBox(height: 20),
              CardBox(
                child: Column(
                  children: [
                    _row(context.tr('fare'), money(r.price)),
                    if (_tip > 0) _row(context.tr('tip'), money(_tip)),
                    const Divider(height: 20),
                    _row(
                      context.tr('total'),
                      money(r.price + _tip),
                      bold: true,
                    ),
                    const SizedBox(height: 6),
                    _row(
                      context.tr('payment'),
                      paymentTypeLabel(context, r.request.payment),
                    ),
                    _row(
                      context.tr('distance'),
                      km(r.request.route.distanceKm),
                    ),
                  ],
                ),
              ),
              if (r.request.payment == PaymentType.cash) ...[
                const SizedBox(height: 10),
                CardBox(
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('pay_driver_cash', {
                            'amount': money(r.price + _tip),
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              CardBox(
                child: Column(
                  children: [
                    Avatar(r.driver.name, size: 56),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('rate_driver', {'name': r.driver.firstName}),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            iconSize: 38,
                            onPressed: () => setState(() => _stars = i),
                            icon: Icon(
                              i <= _stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('add_tip'),
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in _tips)
                          ChoiceChip(
                            label: Text(
                              t == 0 ? context.tr('no_tip') : money(t),
                            ),
                            selected: _tip == t,
                            selectedColor: AppColors.primary,
                            onSelected: (_) => setState(() => _tip = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _comment,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: context.tr('comment_hint'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(context.tr('submit')),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(context.tr('skip')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(
          a,
          style: TextStyle(
            color: bold ? AppColors.ink : AppColors.inkSoft,
            fontWeight: bold ? FontWeight.w700 : null,
          ),
        ),
        const Spacer(),
        Text(
          b,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    ),
  );
}
