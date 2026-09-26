import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/rental_widgets.dart';
import '../common/where_to_sheet.dart';

/// Albanian plates: "AA 123 BB" (older "TR 1234 A" style also accepted).
bool validPlate(String s) =>
    RegExp(r'^[A-Z]{2}\s?\d{3,4}\s?[A-Z]{1,2}$')
        .hasMatch(s.trim().toUpperCase());

/// Common paint colours, shown as swatches.
const carColors = <int, String>{
  0xFFF2F2F2: 'color_white',
  0xFF16181D: 'color_black',
  0xFF9AA3AE: 'color_silver',
  0xFF4A4F57: 'color_grey',
  0xFF1F5AA6: 'color_blue',
  0xFFD9453B: 'color_red',
  0xFF4F6D3A: 'color_green',
  0xFFF6C744: 'color_yellow',
  0xFF7A5534: 'color_brown',
};

class CarFormScreen extends StatefulWidget {
  const CarFormScreen({super.key, this.initial});

  final Car? initial;

  @override
  State<CarFormScreen> createState() => _CarFormScreenState();
}

class _CarFormScreenState extends State<CarFormScreen> {
  late final Car? c = widget.initial;
  late final _make = TextEditingController(text: c?.make);
  late final _model = TextEditingController(text: c?.model);
  late final _year = TextEditingController(text: c == null ? '' : '${c!.year}');
  late final _plate = TextEditingController(text: c?.plate);
  late final _description = TextEditingController(text: c?.description);
  late String _category = c?.categoryId ?? 'economy';
  late int _color = c?.colorValue ?? carColors.keys.first;
  late Transmission _transmission = c?.transmission ?? Transmission.manual;
  late Fuel _fuel = c?.fuel ?? Fuel.diesel;
  late int _seats = c?.seats ?? 5;
  late int _price = c?.pricePerDay ?? Pricing.byId('economy').suggestedPerDay;
  late int _deposit = c?.deposit ?? Pricing.byId('economy').suggestedDeposit;
  late int _minDays = c?.minDays ?? 1;
  late int _kmPerDay = c?.kmPerDay ?? 250;
  late bool _delivery = c?.delivery ?? false;
  late int _deliveryFee = c?.deliveryFee ?? 500;
  late Place? _location = c?.location;
  bool _saving = false;

  @override
  void dispose() {
    for (final t in [_make, _model, _year, _plate, _description]) {
      t.dispose();
    }
    super.dispose();
  }

  void _setCategory(String id) {
    final cat = Pricing.byId(id);
    setState(() {
      _category = id;
      if (widget.initial == null) {
        _price = cat.suggestedPerDay;
        _deposit = cat.suggestedDeposit;
        _seats = cat.seats;
      }
    });
  }

  Future<void> _pickLocation() async {
    final p = await showWhereTo(context, titleKey: 'where_is_car');
    if (p != null) setState(() => _location = p);
  }

  Future<void> _save() async {
    final year = int.tryParse(_year.text.trim());
    final now = DateTime.now().year;
    String? error;
    if (_make.text.trim().isEmpty || _model.text.trim().isEmpty) {
      error = 'fill_make_model';
    } else if (year == null || year < 1990 || year > now + 1) {
      error = 'invalid_year';
    } else if (!validPlate(_plate.text)) {
      error = 'invalid_plate';
    } else if (_location == null) {
      error = 'choose_car_location';
    }
    if (error != null) {
      showInfo(context, context.tr(error));
      return;
    }
    final app = context.read<AppState>();
    final car = Car(
      id: c?.id ?? '',
      ownerId: c?.ownerId ?? app.backend.currentUserId,
      ownerName: c?.ownerName ?? app.user?.name ?? '',
      ownerPhone: app.user?.phone ?? '',
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: year!,
      plate: _plate.text.trim().toUpperCase(),
      colorValue: _color,
      categoryId: _category,
      transmission: _transmission,
      fuel: _fuel,
      seats: _seats,
      pricePerDay: _price,
      deposit: _deposit,
      location: _location!,
      delivery: _delivery,
      deliveryFee: _delivery ? _deliveryFee : 0,
      minDays: _minDays,
      kmPerDay: _kmPerDay,
      description: _description.text.trim(),
      rating: c?.rating ?? 5,
      trips: c?.trips ?? 0,
      listed: c?.listed ?? true,
    );
    setState(() => _saving = true);
    try {
      final saved = await app.backend.saveCar(car);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(c == null ? 'add_car' : 'edit_car')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: CarTopView(color: Color(_color), size: 150),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in carColors.entries)
                  Tooltip(
                    message: context.tr(e.value),
                    child: InkWell(
                      onTap: () => setState(() => _color = e.key),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(e.key),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == e.key
                                ? AppColors.ink
                                : AppColors.border,
                            width: _color == e.key ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SectionLabel(context.tr('car_details')),
            TextField(
              controller: _make,
              decoration: InputDecoration(
                labelText: context.tr('make'),
                hintText: 'Volkswagen',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              decoration: InputDecoration(
                labelText: context.tr('model'),
                hintText: 'Golf 7',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: context.tr('year'),
                      hintText: '2019',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _plate,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: context.tr('plate'),
                      hintText: 'AA 123 BB',
                    ),
                  ),
                ),
              ],
            ),
            SectionLabel(context.tr('car_type')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in Pricing.categories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(cat.id), size: 16),
                    label: Text(context.tr(cat.nameKey)),
                    selected: _category == cat.id,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => _setCategory(cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _segmented<Transmission>(
              Transmission.values,
              _transmission,
              (t) => transmissionLabel(context, t),
              (t) => setState(() => _transmission = t),
            ),
            const SizedBox(height: 10),
            _segmented<Fuel>(
              Fuel.values,
              _fuel,
              (f) => fuelLabel(context, f),
              (f) => setState(() => _fuel = f),
            ),
            const SizedBox(height: 6),
            _stepper(
              context.tr('seats'),
              '$_seats',
              () => setState(() => _seats = (_seats - 1).clamp(2, 9)),
              () => setState(() => _seats = (_seats + 1).clamp(2, 9)),
            ),
            SectionLabel(context.tr('price_and_rules')),
            _stepper(
              context.tr('price_per_day'),
              money(_price),
              () => setState(() => _price = (_price - 100).clamp(500, 1000000)),
              () => setState(() => _price += 100),
              hint: context.tr('suggested_price', {
                'p': money(Pricing.byId(_category).suggestedPerDay),
              }),
            ),
            _stepper(
              context.tr('deposit'),
              money(_deposit),
              () => setState(
                () => _deposit = (_deposit - 5000).clamp(0, 10000000),
              ),
              () => setState(() => _deposit += 5000),
            ),
            _stepper(
              context.tr('min_rental'),
              context.tr('n_days', {'n': '$_minDays'}),
              () => setState(() => _minDays = (_minDays - 1).clamp(1, 30)),
              () => setState(() => _minDays = (_minDays + 1).clamp(1, 30)),
            ),
            _stepper(
              context.tr('mileage'),
              context.tr('km_per_day', {'n': '$_kmPerDay'}),
              () =>
                  setState(() => _kmPerDay = (_kmPerDay - 50).clamp(100, 1000)),
              () =>
                  setState(() => _kmPerDay = (_kmPerDay + 50).clamp(100, 1000)),
            ),
            SectionLabel(context.tr('pickup_location')),
            CardBox(
              onTap: _pickLocation,
              child: Row(
                children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _location?.name ?? context.tr('choose_car_location'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _location == null
                            ? AppColors.inkFaint
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _delivery,
              activeTrackColor: AppColors.success,
              title: Text(context.tr('offer_delivery')),
              subtitle: Text(context.tr('offer_delivery_desc')),
              onChanged: (v) => setState(() => _delivery = v),
            ),
            if (_delivery)
              _stepper(
                context.tr('delivery_fee'),
                _deliveryFee == 0 ? context.tr('free') : money(_deliveryFee),
                () => setState(
                  () => _deliveryFee = (_deliveryFee - 100).clamp(0, 100000),
                ),
                () => setState(() => _deliveryFee += 100),
              ),
            SectionLabel(context.tr('description')),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.tr('description_hint'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(context.tr(c == null ? 'publish_car' : 'save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented<T>(
    List<T> values,
    T selected,
    String Function(T) label,
    ValueChanged<T> onChanged,
  ) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<T>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
      ),
      segments: [
        for (final v in values) ButtonSegment(value: v, label: Text(label(v))),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    ),
  );

  Widget _stepper(
    String label,
    String value,
    VoidCallback minus,
    VoidCallback plus, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.inkSoft)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkFaint,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: context.tr('decrease'),
          onPressed: minus,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: context.tr('increase'),
          onPressed: plus,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}
