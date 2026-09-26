import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// Big pill with a red round knob: slide it to the end (or tap) to act.
/// The ">>>" hint on the right pulses gently to invite the swipe.
class SlideAction extends StatefulWidget {
  const SlideAction({
    super.key,
    required this.label,
    required this.onSubmit,
    this.icon = Icons.arrow_forward_rounded,
    this.enabled = true,
    this.loading = false,
    this.height = 68,
  });

  final String label;
  final VoidCallback onSubmit;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final double height;

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction>
    with TickerProviderStateMixin {
  late final _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(count: 4);
  late final _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  double _drag = 0;
  double _snapFrom = 0;
  double _snapTo = 0;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      setState(() {
        _drag =
            _snapFrom +
            (_snapTo - _snapFrom) * Curves.easeOut.transform(_snap.value);
      });
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    _snap.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && !widget.loading;

  void _animateTo(double target, {VoidCallback? then}) {
    _snapFrom = _drag;
    _snapTo = target;
    _snap.forward(from: 0).whenComplete(() => then?.call());
  }

  void _submit(double max) {
    _animateTo(
      max,
      then: () {
        widget.onSubmit();
        if (mounted) _animateTo(0);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final pad = 6.0;
    final knob = h - pad * 2;
    return Semantics(
      button: true,
      enabled: _active,
      label: widget.label,
      excludeSemantics: true,
      onTap: _active ? widget.onSubmit : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final max = box.maxWidth - knob - pad * 2;
          final progress = max <= 0 ? 0.0 : (_drag / max).clamp(0.0, 1.0);
          return GestureDetector(
            onTap: _active ? () => _submit(max) : null,
            onHorizontalDragUpdate: _active
                ? (d) => setState(
                    () => _drag = (_drag + d.delta.dx).clamp(0.0, max),
                  )
                : null,
            onHorizontalDragEnd: _active
                ? (_) => progress > 0.7 ? _submit(max) : _animateTo(0)
                : null,
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(h / 2),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Red trail behind the knob while dragging.
                  Positioned(
                    left: pad,
                    top: pad,
                    bottom: pad,
                    width: knob + _drag,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(knob / 2),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.0),
                            AppColors.primary.withValues(
                              alpha: 0.35 * progress,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(left: knob + 12, right: 64),
                      child: Opacity(
                        opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                        child: Center(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _active
                                  ? AppColors.ink
                                  : AppColors.inkFaint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 22,
                    child: AnimatedBuilder(
                      animation: _hint,
                      builder: (context, _) => Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Opacity(
                              opacity: _active ? _chevronOpacity(i) : 0.2,
                              child: const Text(
                                '›',
                                style: TextStyle(
                                  fontSize: 26,
                                  height: 1,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: pad + _drag,
                    child: Container(
                      width: knob,
                      height: knob,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _active
                            ? AppColors.primary
                            : AppColors.surfaceHigh,
                        boxShadow: _active
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: widget.loading
                          ? const Padding(
                              padding: EdgeInsets.all(17),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.icon,
                              color: _active
                                  ? Colors.white
                                  : AppColors.inkFaint,
                              size: 24,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _chevronOpacity(int i) {
    final t = (_hint.value * 3 - i) % 3;
    return t < 1 ? 0.35 + 0.65 * (1 - (t - 0.5).abs() * 2) : 0.35;
  }
}

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = false});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool badge;
}

/// Floating dark pill with icons; the active one sits in a red circle.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppColors.border),
              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 24)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _item(items[i], i == index, () => onTap(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(NavItem item, bool active, VoidCallback onTap) {
    return Tooltip(
      message: item.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: active,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 54,
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.primary : Colors.transparent,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  color: active ? Colors.white : AppColors.inkSoft,
                  size: 24,
                ),
                if (item.badge && !active)
                  Positioned(
                    top: 13,
                    right: 13,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Top trends            See all ›"
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 0, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.inkSoft,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Heart toggle that remembers the car in the user's favourites.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.carId,
    this.size = 40,
    this.color = const Color(0x33000000),
  });

  final String carId;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fav = app.isFavorite(carId);
    return Tooltip(
      message: context.tr(fav ? 'remove_favorite' : 'add_favorite'),
      child: Material(
        color: color,
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => app.toggleFavorite(carId),
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(fav),
                size: size * 0.5,
                color: fav ? AppColors.primary : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round badge with the make's initials, standing in for a brand logo.
class MakeBadge extends StatelessWidget {
  const MakeBadge(this.car, {super.key, this.size = 48});

  final Car car;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = car.make.trim().split(RegExp(r'[\s-]+'));
    final text = words.length > 1
        ? words.take(2).map((w) => w.isEmpty ? '' : w[0]).join()
        : car.make.characters.take(2).toString();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFD5D8DC)],
        ),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Small dark tile with an icon, a value and a caption (e.g. "Automatik /
/// Kutia"), with a faint red glow in the corner like the design.
class SpecTile extends StatelessWidget {
  const SpecTile({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    this.glow = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool glow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: compact ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        gradient: glow
            ? RadialGradient(
                center: const Alignment(-0.9, 1.1),
                radius: 1.3,
                colors: [
                  AppColors.primary.withValues(alpha: 0.13),
                  AppColors.surface,
                ],
              )
            : null,
      ),
      child: compact
          ? Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 10),
                Expanded(child: _texts()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 24, color: AppColors.ink),
                const SizedBox(height: 16),
                _texts(),
              ],
            ),
    );
  }

  Widget _texts() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 2),
      Text(
        caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
      ),
    ],
  );
}
