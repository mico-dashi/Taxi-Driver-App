import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/rental_widgets.dart';
import '../common/booking_screen.dart';
import '../common/payment_widgets.dart';
import '../common/where_to_sheet.dart';

/// Dates → Payment → Offer, then the request goes to the owner.
class BookCarScreen extends StatefulWidget {
  const BookCarScreen({super.key, required this.car});

  final Car car;

  @override
  State<BookCarScreen> createState() => _BookCarScreenState();
}

class _BookCarScreenState extends State<BookCarScreen> {
  int _step = 0;
  Pickup _pickup = Pickup.atOwner;
  Place? _address;
  late int _offer = widget.car.pricePerDay;
  final _note = TextEditingController();
  bool _sending = false;

  Car get car => widget.car;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  void _next() {
    if (_step == 0 && _pickup == Pickup.delivery && _address == null) {
      showInfo(context, context.tr('enter_delivery_address'));
      return;
    }
    setState(() => _step++);
  }

  Future<void> _pickDates() async {
    final app = context.read<AppState>();
    final r = await pickRentalDates(
      context,
      start: app.searchStart,
      end: app.searchEnd,
    );
    if (r != null) app.setSearch(start: r.$1, end: r.$2);
  }

  Future<void> _pickAddress() async {
    final p = await showWhereTo(context, titleKey: 'delivery_address');
    if (p != null) setState(() => _address = p);
  }

  Future<void> _send() async {
    final app = context.read<AppState>();
    setState(() => _sending = true);
    try {
      final booking = await app.backend.requestBooking(
        car: car,
        start: app.searchStart,
        end: app.searchEnd,
        offeredPerDay: _offer,
        pickup: _pickup,
        payment: app.selectedPayment.type,
        deliveryAddress: _pickup == Pickup.delivery
            ? [
                _address!.name,
                _address!.subtitle,
              ].where((s) => s.isNotEmpty).join(', ')
            : '',
        note: _note.text.trim(),
        promoCode: app.promoCode ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => BookingScreen(initial: booking),
        ),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr('step_dates'),
      context.tr('step_payment'),
      context.tr('step_offer'),
    ];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StepHeader(step: _step, labels: labels, onBack: _back),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  children: [
                    _carSummary(),
                    const SizedBox(height: 16),
                    ...switch (_step) {
                      0 => _datesStep(),
                      1 => _paymentStep(),
                      _ => _offerStep(),
                    },
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carSummary() => CardBox(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CarBadge.of(car, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                car.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${car.ownerName} · ${car.location.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        Text(
          '${money(car.pricePerDay)}${context.tr('per_day_short')}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  List<Widget> _datesStep() {
    final app = context.watch<AppState>();
    return [
      Text(
        context.tr('when_need_car'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      DatesField(start: app.searchStart, end: app.searchEnd, onTap: _pickDates),
      if (rentalDays(app.searchStart, app.searchEnd) < car.minDays) ...[
        const SizedBox(height: 8),
        Pill(
          context.tr('min_days_note', {'n': '${car.minDays}'}),
          color: AppColors.dangerSoft,
          textColor: AppColors.danger,
        ),
      ],
      SectionLabel(context.tr('how_get_car')),
      _pickupOption(
        Pickup.atOwner,
        Icons.place_outlined,
        context.tr('pickup_at_owner'),
        car.location.name,
      ),
      if (car.delivery) ...[
        const SizedBox(height: 8),
        _pickupOption(
          Pickup.delivery,
          Icons.local_shipping_outlined,
          context.tr('delivery_to_me'),
          car.deliveryFee == 0
              ? context.tr('free_delivery')
              : context.tr('delivery_for', {'p': money(car.deliveryFee)}),
        ),
        if (_pickup == Pickup.delivery) ...[
          const SizedBox(height: 8),
          CardBox(
            onTap: _pickAddress,
            child: Row(
              children: [
                const Icon(Icons.home_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _address?.name ?? context.tr('enter_delivery_address'),
                    style: TextStyle(
                      color: _address == null
                          ? AppColors.inkFaint
                          : AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ],
    ];
  }

  Widget _pickupOption(
    Pickup p,
    IconData icon,
    String title,
    String subtitle,
  ) => CardBox(
    selected: _pickup == p,
    onTap: () => setState(() => _pickup = p),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        Icon(
          _pickup == p
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color: _pickup == p ? AppColors.primary : AppColors.inkFaint,
        ),
      ],
    ),
  );

  List<Widget> _paymentStep() => [
    Text(
      context.tr('how_pay'),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 4),
    Text(
      context.tr('charged_after'),
      style: const TextStyle(color: AppColors.inkSoft),
    ),
    const PaymentMethodList(),
  ];

  List<Widget> _offerStep() {
    final app = context.watch<AppState>();
    final days = rentalDays(app.searchStart, app.searchEnd);
    final min = Pricing.minOffer(car.pricePerDay);
    final quote = Pricing.quote(
      perDay: _offer,
      days: days,
      deposit: car.deposit,
      deliveryFee: _pickup == Pickup.delivery ? car.deliveryFee : 0,
      promoPercent: app.promoPercent,
    );
    final below = _offer < car.pricePerDay;
    return [
      Text(
        context.tr('your_offer_title'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        context.tr('your_offer_desc'),
        style: const TextStyle(color: AppColors.inkSoft),
      ),
      const SizedBox(height: 16),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('price_per_day'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  Text(
                    money(_offer),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    below
                        ? context.tr('below_listed', {
                            'p': money(car.pricePerDay),
                          })
                        : context.tr('listed_price'),
                    style: TextStyle(
                      fontSize: 12,
                      color: below ? AppColors.primaryLight : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: context.tr('decrease'),
              onPressed: _offer - 100 >= min
                  ? () => setState(() => _offer -= 100)
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: context.tr('increase'),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _offer + 100 <= car.pricePerDay
                  ? () => setState(() => _offer += 100)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      PriceBreakdown(quote: quote),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        maxLines: 2,
        decoration: InputDecoration(hintText: context.tr('note_to_owner')),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.tr('request_info'),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _bottomBar() {
    final app = context.watch<AppState>();
    final tooShort = rentalDays(app.searchStart, app.searchEnd) < car.minDays;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PaymentChip(
              method: app.selectedPayment,
              prefix: context.tr('pay_with'),
              onTap: _step == 2 ? () => setState(() => _step = 1) : null,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: tooShort || _sending
                ? null
                : (_step < 2 ? _next : _send),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 52)),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(context.tr(_step < 2 ? 'continue' : 'send_request')),
          ),
        ],
      ),
    );
  }
}
