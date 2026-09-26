import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'car_art.dart';

/// Initials avatar (no photos needed; works offline).
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 44});

  final String name;
  final double size;

  static const _palette = [
    Color(0xFF7A1119),
    Color(0xFF24466E),
    Color(0xFF2B5A45),
    Color(0xFF6B4F1D),
    Color(0xFF4B3470),
    Color(0xFF3C474F),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

IconData categoryIcon(String categoryId) => switch (categoryId) {
  'luxury' => Icons.workspace_premium_rounded,
  'van' => Icons.airport_shuttle_rounded,
  'suv' => Icons.terrain_rounded,
  _ => Icons.directions_car_filled_rounded,
};

/// The car's "photo": a side-view drawing of the car in its own colour on
/// a dark tile. Owners can add real photos later (see docs/GOING_LIVE.md).
class CarBadge extends StatelessWidget {
  const CarBadge({
    super.key,
    required this.color,
    this.shape = CarShape.hatch,
    this.size = 56,
  });

  CarBadge.of(Car car, {super.key, this.size = 56})
    : color = Color(car.colorValue),
      shape = shapeFor(car);

  final Color color;
  final CarShape shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.5,
      height: size,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, 0.3),
          radius: 0.9,
          colors: [Color(0xFF3A3D41), AppColors.surfaceHigh],
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      alignment: Alignment.center,
      child: CarSideView(color: color, shape: shape, width: size * 1.36),
    );
  }
}

class Rating extends StatelessWidget {
  const Rating(this.value, {super.key, this.trips});

  final double value;
  final int? trips;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        if (trips != null) ...[
          Flexible(
            child: Text(
              ' · ${context.tr('n_trips', {'n': '$trips'})}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
        ],
      ],
    );
  }
}

class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key, this.verified = true, this.style});

  final String name;
  final bool verified;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style:
                style ??
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        if (verified) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.verified_rounded,
            size: 15,
            color: AppColors.verified,
          ),
        ],
      ],
    );
  }
}

class Plate extends StatelessWidget {
  const Plate(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF2155C4),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'AL',
              style: TextStyle(fontSize: 5, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White card used for the bottom panels over the map.
class SheetCard extends StatelessWidget {
  const SheetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.selected = false,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small pill, e.g. "• 9 afër" or "Ofertë e re".
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = AppColors.successSoft,
    this.textColor = AppColors.success,
    this.dot = true,
  });

  final String text;
  final Color color;
  final Color textColor;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup (red) → destination (yellow) summary used on several screens.
class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.pickup,
    required this.destination,
    this.trailing,
  });

  final String pickup;
  final String destination;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Column(
            children: [
              _dot(AppColors.pickup),
              Container(width: 1.5, height: 18, color: AppColors.border),
              _dot(AppColors.destination),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  static Widget _dot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.surface,
      border: Border.all(color: c, width: 3.5),
    ),
  );
}

/// Step progress header (e.g. Dates / Payment / Offer).
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.labels,
    required this.onBack,
  });

  final int step;
  final List<String> labels;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(icon: Icons.chevron_left_rounded, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: i <= step ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  _StepDot(index: i, current: step),
                  const SizedBox(width: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i <= step ? AppColors.ink : AppColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.current});

  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? AppColors.primary
            : (done ? AppColors.primarySoft : AppColors.surfaceHigh),
      ),
      child: done
          ? const Icon(
              Icons.check_rounded,
              size: 12,
              color: AppColors.primaryLight,
            )
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.inkFaint,
              ),
            ),
    );
  }
}

/// Round dark button used in the top bars (back, search, favourite).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.color = AppColors.surface,
    this.iconColor = AppColors.ink,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.46),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Floating status pill at the top of map screens ("Searching nearby…").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.trailing,
  });

  final String text;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class PaymentIcon extends StatelessWidget {
  const PaymentIcon(this.method, {super.key});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (method.type) {
      PaymentType.cash => (Icons.payments_rounded, AppColors.success),
      PaymentType.card => (Icons.credit_card_rounded, AppColors.info),
      PaymentType.applePay => (Icons.apple_rounded, AppColors.ink),
      PaymentType.googlePay => (
        Icons.g_mobiledata_rounded,
        const Color(0xFF4285F4),
      ),
    };
    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

String paymentLabel(BuildContext context, PaymentMethod m) => switch (m.type) {
  PaymentType.cash => context.tr('pay_cash'),
  PaymentType.applePay => 'Apple Pay',
  PaymentType.googlePay => 'Google Pay',
  PaymentType.card => m.label,
};

String paymentTypeLabel(BuildContext context, PaymentType t) => switch (t) {
  PaymentType.cash => context.tr('pay_cash'),
  PaymentType.card => context.tr('pay_card'),
  PaymentType.applePay => 'Apple Pay',
  PaymentType.googlePay => 'Google Pay',
};

void showError(BuildContext context, Object error) {
  final code = error is Exception ? errorCode(error) : 'generic';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.trError(code)),
      backgroundColor: AppColors.danger,
    ),
  );
}

void showInfo(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
