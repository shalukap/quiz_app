import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Makes the subscription state available to widgets and rebuilds them when it
/// changes, so the premium look applies instantly after purchase.
class PremiumScope extends InheritedNotifier<SubscriptionService> {
  PremiumScope({super.key, required super.child})
      : super(notifier: SubscriptionService.instance);

  /// Registers [context] for rebuilds and returns whether Premium is active.
  static bool watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<PremiumScope>();
    return PremiumStyle.active;
  }
}

/// Gold "PREMIUM" crown chip.
class PremiumBadge extends StatelessWidget {
  final String label;
  final bool compact;
  const PremiumBadge({super.key, this.label = 'Premium', this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(color: PremiumStyle.gold.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: -2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: compact ? 12 : 14, color: PremiumStyle.onGold),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: AppText.style(
              size: compact ? 9.5 : 10.5,
              weight: FontWeight.w800,
              spacing: 0.8,
              color: PremiumStyle.onGold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated aurora backdrop used behind every screen.
class AuroraBackground extends StatefulWidget {
  final Widget? child;

  /// Forces the gold premium palette (e.g. on the paywall). Defaults to the
  /// user's subscription state.
  final bool? premium;
  const AuroraBackground({super.key, this.child, this.premium});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.premium ?? PremiumScope.watch(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.bg),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _AuroraPainter(_controller.value * 2 * math.pi, premium),
            ),
          ),
        ),
        // Subtle vignette to keep content readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x99060914)],
              stops: [0.45, 1],
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool premium;
  _AuroraPainter(this.t, this.premium);

  void _blob(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _blob(
      canvas,
      size,
      Offset(w * (0.85 + 0.08 * math.sin(t)), h * (0.08 + 0.05 * math.cos(t))),
      w * 0.95,
      (premium ? const Color(0xFFE09A1F) : const Color(0xFF2F4BFF)).withValues(alpha: premium ? 0.34 : 0.38),
    );
    _blob(
      canvas,
      size,
      Offset(w * (0.05 + 0.1 * math.cos(t)), h * (0.35 + 0.06 * math.sin(t))),
      w * 0.8,
      const Color(0xFF7C3AED).withValues(alpha: premium ? 0.30 : 0.26),
    );
    _blob(
      canvas,
      size,
      Offset(w * (0.7 + 0.1 * math.sin(t + 2)), h * (0.92 + 0.04 * math.cos(t + 1))),
      w * 0.85,
      (premium ? const Color(0xFFDB2777) : const Color(0xFF0891B2)).withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t || oldDelegate.premium != premium;
}

/// Scales its child down slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({super.key, required this.child, this.onTap, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Frosted glass surface with a gradient fill and hairline border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? accent;
  final bool blur;
  final double strength;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.lg,
    this.onTap,
    this.accent,
    this.blur = false,
    this.strength = 1,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: accent == null
            ? AppGradients.glass(strength: strength)
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent!.withValues(alpha: 0.18),
                  accent!.withValues(alpha: 0.05),
                ],
              ),
        border: Border.all(
          color: accent?.withValues(alpha: 0.55) ?? AppColors.glassStroke,
          width: accent == null ? 1 : 1.4,
        ),
        boxShadow: accent == null
            ? null
            : [
                BoxShadow(
                  color: accent!.withValues(alpha: 0.22),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      );
    }

    if (onTap == null) return content;
    return Pressable(onTap: onTap, child: content);
  }
}

/// Round glass icon button for app bars and toolbars.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final bool active;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.36),
          color: active ? tint.withValues(alpha: 0.18) : AppColors.glassFill,
          border: Border.all(
            color: active ? tint.withValues(alpha: 0.7) : AppColors.glassStroke,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.45,
          color: active ? Color.lerp(tint, Colors.white, 0.35) : Colors.white,
        ),
      ),
    );
  }
}

class GlassBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  const GlassBackButton({super.key, this.onTap, this.icon = Icons.arrow_back_ios_new_rounded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassIconButton(
        icon: icon,
        size: 40,
        onTap: onTap ?? () => Navigator.maybePop(context),
      ),
    );
  }
}

/// Transparent app bar with a glass back button.
AppBar glassAppBar(
  BuildContext context, {
  String? title,
  Widget? leading,
  List<Widget>? actions,
  bool showBack = true,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    leadingWidth: 64,
    leading: leading ??
        (showBack
            ? const Padding(padding: EdgeInsets.only(left: 16), child: GlassBackButton())
            : null),
    title: title == null ? null : Text(title),
    actions: [
      ...?actions,
      const SizedBox(width: 12),
    ],
  );
}

/// Primary call-to-action with gradient fill and glow.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  /// Defaults to the brand gradient (gold for Premium members).
  final Gradient? gradient;

  /// Label/icon color; defaults to a color that reads well on [gradient].
  final Color? foregroundColor;
  final Color? glowColor;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 56,
    this.gradient,
    this.foregroundColor,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    PremiumScope.watch(context);
    final enabled = onPressed != null && !loading;
    final fg = foregroundColor ?? (gradient == null ? AppGradients.onPrimary : Colors.white);
    final glow = glowColor ?? (gradient == null ? AppGradients.glow : AppColors.primary);
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient ?? AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: fg, strokeWidth: 2.2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.style(size: 15, weight: FontWeight.w800, spacing: 0.2, color: fg),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: fg, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary glass button.
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final double height;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.glass(),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassStroke),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppText.style(size: 15, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overline + big title + optional subtitle.
class PageHeader extends StatelessWidget {
  final String? overline;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({super.key, this.overline, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null) ...[
                Text(overline!.toUpperCase(), style: AppText.overline()),
                const SizedBox(height: 8),
              ],
              Text(title, style: AppText.display()),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: AppText.body()),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Thin animated progress bar with a glowing gradient fill.
class GlowProgressBar extends StatelessWidget {
  final double value;
  final double height;
  const GlowProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    PremiumScope.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(height),
          ),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              width: constraints.maxWidth * v,
              decoration: BoxDecoration(
                gradient: AppGradients.progress,
                borderRadius: BorderRadius.circular(height),
                boxShadow: [
                  BoxShadow(
                    color: AppGradients.glow.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Step x of y" indicator used by the quiz setup flow.
class StepProgress extends StatelessWidget {
  final int step;
  final int total;
  const StepProgress({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final premium = PremiumScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STEP $step OF $total',
              style: AppText.style(size: 11, weight: FontWeight.w700, spacing: 1.2, color: AppColors.textMuted),
            ),
            const Spacer(),
            Text(
              '${(step / total * 100).round()}%',
              style: AppText.style(size: 11, weight: FontWeight.w800, spacing: 1, color: premium ? PremiumStyle.gold : AppColors.cyan),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(total, (i) {
            final done = i < step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: done ? AppGradients.progress : null,
                  color: done ? null : Colors.white.withValues(alpha: 0.08),
                  boxShadow: done
                      ? [BoxShadow(color: AppGradients.glow.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Small tinted chip.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool uppercase;

  const Pill({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Color.lerp(color, Colors.white, 0.3)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style: AppText.style(size: 10.5, weight: FontWeight.w800, spacing: 0.6, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Gradient rounded-square icon with a soft glow.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool muted;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 52,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: muted ? null : AppGradients.accent(color),
        color: muted ? Colors.white.withValues(alpha: 0.06) : null,
        border: Border.all(color: Colors.white.withValues(alpha: muted ? 0.08 : 0.22)),
        boxShadow: muted
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Icon(icon, color: muted ? AppColors.textMuted : Colors.white, size: size * 0.48),
    );
  }
}

/// Uppercase section label with an accent icon.
class SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const SectionLabel(this.text, {super.key, this.icon, this.color = AppColors.primaryLight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
        ],
        Text(text.toUpperCase(), style: AppText.overline(color: color)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.glass(strength: 1.4),
                border: Border.all(color: AppColors.glassStroke),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 40),
                ],
              ),
              child: Icon(icon, size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppText.title(), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppText.body(color: AppColors.textMuted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 3, strokeCap: StrokeCap.round),
      ),
    );
  }
}

/// Staggered fade + slide entrance for list items.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.08).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (delay * 1000).round()),
      curve: Interval(delay / (0.45 + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
    );
  }
}

/// Container styling for modal bottom sheets.
class GlassSheet extends StatelessWidget {
  final Widget child;
  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border(top: BorderSide(color: AppColors.glassStroke)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

const appNavItems = [
  NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
  NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
  NavItem(Icons.bookmark_outline_rounded, Icons.bookmark_rounded, 'Saved'),
  NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

/// Floating pill-shaped bottom navigation.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    PremiumScope.watch(context);
    final onPrimary = AppGradients.onPrimary;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.glassStroke),
              ),
              child: Row(
                children: List.generate(appNavItems.length, (i) {
                  final item = appNavItems[i];
                  final selected = i == currentIndex;
                  return Expanded(
                    child: Pressable(
                      onTap: () => onTap(i),
                      pressedScale: 0.9,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: selected ? AppGradients.primary : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppGradients.glow.withValues(alpha: 0.5),
                                    blurRadius: 16,
                                    spreadRadius: -4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: selected ? onPrimary : AppColors.textMuted,
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: AppText.style(size: 12, weight: FontWeight.w700, color: onPrimary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
