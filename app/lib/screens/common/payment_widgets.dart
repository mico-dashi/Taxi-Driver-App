import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Cash / cards / wallets picker (payment step and profile).
class PaymentMethodList extends StatelessWidget {
  const PaymentMethodList({super.key, this.manage = false});

  /// In the profile, cards can be removed.
  final bool manage;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cards = app.paymentMethods
        .where((m) => m.type == PaymentType.card)
        .toList();
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final wallet = isApple
        ? const PaymentMethod(
            id: 'apple_pay',
            type: PaymentType.applePay,
            label: 'Apple Pay',
          )
        : const PaymentMethod(
            id: 'google_pay',
            type: PaymentType.googlePay,
            label: 'Google Pay',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(context.tr('pay_cash')),
        _MethodTile(
          method: PaymentMethod.cash,
          subtitle: context.tr('pay_cash_desc'),
          selected: app.selectedPaymentId == PaymentMethod.cash.id,
          onTap: () => app.selectPayment(PaymentMethod.cash.id),
        ),
        if (AppConfig.cardPaymentsEnabled) ...[
          SectionLabel(context.tr('cards')),
          for (final c in cards)
            _MethodTile(
              method: c,
              subtitle: c.detail,
              selected: app.selectedPaymentId == c.id,
              onTap: () => app.selectPayment(c.id),
              onDelete: manage ? () => app.removePaymentMethod(c.id) : null,
            ),
          OutlinedButton.icon(
            onPressed: () => showAddCard(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.tr('add_card')),
          ),
          SectionLabel(context.tr('digital_wallets')),
          _MethodTile(
            method: wallet,
            subtitle: context.tr(
              isApple ? 'confirm_face_id' : 'confirm_google',
            ),
            selected: app.selectedPaymentId == wallet.id,
            onTap: () async {
              if (!app.paymentMethods.any((m) => m.id == wallet.id)) {
                await app.addPaymentMethod(wallet);
              } else {
                await app.selectPayment(wallet.id);
              }
            },
          ),
        ],
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final PaymentMethod method;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            PaymentIcon(method),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paymentLabel(context, method),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primaryLight : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentChip extends StatelessWidget {
  const PaymentChip({
    super.key,
    required this.method,
    required this.prefix,
    this.onTap,
  });

  final PaymentMethod method;
  final String prefix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          PaymentIcon(method),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prefix,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkFaint,
                  ),
                ),
                Text(
                  paymentLabel(context, method),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}

Future<void> showAddCard(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => const _AddCardSheet(),
);

/// Detects the card network from the number prefix.
String? cardBrand(String digits) {
  if (digits.startsWith('4')) return 'Visa';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'Mastercard';
  if (RegExp(r'^3[47]').hasMatch(digits)) return 'American Express';
  return null;
}

bool luhnValid(String digits) {
  if (digits.length < 13) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var n = int.parse(digits[digits.length - 1 - i]);
    if (i.isOdd) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 == 0;
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  void _save() {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    final brand = cardBrand(digits);
    final exp = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(_expiry.text);
    if (brand == null || !luhnValid(digits)) {
      setState(() => _error = context.tr('card_invalid'));
      return;
    }
    if (exp == null) {
      setState(() => _error = context.tr('expiry_invalid'));
      return;
    }
    final now = DateTime.now();
    final year = 2000 + int.parse(exp.group(2)!);
    final month = int.parse(exp.group(1)!);
    if (year < now.year || (year == now.year && month < now.month)) {
      setState(() => _error = context.tr('card_expired'));
      return;
    }
    if (_cvc.text.length < 3) {
      setState(() => _error = context.tr('cvc_invalid'));
      return;
    }
    // Only brand + last 4 are kept on the phone. The full number must go
    // straight to the payment provider's SDK (tokenisation) in production.
    final last4 = digits.substring(digits.length - 4);
    context.read<AppState>().addPaymentMethod(
      PaymentMethod(
        id: 'card_$last4',
        type: PaymentType.card,
        label: brand,
        detail: '•••• $last4 · ${_expiry.text}',
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('add_card'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(23),
            ],
            decoration: InputDecoration(
              hintText: context.tr('card_number'),
              prefixIcon: const Icon(Icons.credit_card_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiry,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [LengthLimitingTextInputFormatter(5)],
                  decoration: const InputDecoration(hintText: 'MM/YY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvc,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(hintText: 'CVC'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('card_secure'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: Text(context.tr('save'))),
        ],
      ),
    );
  }
}
