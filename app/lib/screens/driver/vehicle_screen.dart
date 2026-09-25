import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/pricing.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Albanian plates: "AA 123 BB" (older "TR 1234 A" style also accepted).
bool validPlate(String s) =>
    RegExp(r'^[A-Z]{2}\s?\d{3,4}\s?[A-Z]{1,2}$')
        .hasMatch(s.trim().toUpperCase());

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, this.initial, this.required = false});

  final Vehicle? initial;

  /// First-time setup: no back button.
  final bool required;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late final _make = TextEditingController(text: widget.initial?.make);
  late final _model = TextEditingController(text: widget.initial?.model);
  late final _plate = TextEditingController(text: widget.initial?.plate);
  late final _color = TextEditingController(text: widget.initial?.color);
  late String _category = widget.initial?.categoryId ?? 'standard';
  bool _saving = false;

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _plate.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_make.text.trim().isEmpty || _model.text.trim().isEmpty) {
      showInfo(context, context.tr('fill_all_fields'));
      return;
    }
    if (!validPlate(_plate.text)) {
      showInfo(context, context.tr('invalid_plate'));
      return;
    }
    setState(() => _saving = true);
    try {
      final vehicle = Vehicle(
        make: _make.text.trim(),
        model: _model.text.trim(),
        plate: _plate.text.trim().toUpperCase(),
        color: _color.text.trim(),
        categoryId: _category,
        seats: Pricing.byId(_category).seats,
      );
      await context.read<AppState>().backend.saveVehicle(vehicle);
      if (mounted) Navigator.pop(context, vehicle);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.required,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.required,
          title: Text(context.tr('your_vehicle')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                context.tr('vehicle_intro'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _make,
                decoration: InputDecoration(
                  labelText: context.tr('make'),
                  hintText: 'Mercedes-Benz',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                decoration: InputDecoration(
                  labelText: context.tr('model'),
                  hintText: 'E 220d',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: context.tr('plate'),
                  hintText: 'AA 123 BB',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _color,
                decoration: InputDecoration(labelText: context.tr('color')),
              ),
              SectionLabel(context.tr('service_type')),
              for (final c in Pricing.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CardBox(
                    selected: _category == c.id,
                    onTap: () => setState(() => _category = c.id),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CarBadge(categoryId: c.id, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr(c.nameKey),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                context.tr('${c.nameKey}_desc'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(context.tr('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
