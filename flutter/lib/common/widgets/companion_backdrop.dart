import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../companion_theme.dart';

enum CompanionBackdropVariant { shell, sidebar, hero }

/// Static cosmic art used behind the main shell, sidebar and connection hero.
class CompanionBackdrop extends StatelessWidget {
  const CompanionBackdrop(
      {super.key,
      this.child,
      this.variant = CompanionBackdropVariant.shell,
      this.stars = true,
      this.glow = true});

  final Widget? child;
  final CompanionBackdropVariant variant;
  final bool stars;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final dark = CompanionTheme.isDark(context);
    final gradient = switch (variant) {
      CompanionBackdropVariant.shell => CompanionTheme.shellGradient(dark),
      CompanionBackdropVariant.sidebar => CompanionTheme.sidebarGradient(dark),
      CompanionBackdropVariant.hero => CompanionTheme.heroGradient(dark),
    };
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(children: [
          if (glow || stars)
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(
                        painter: _CosmicPainter(
                            dark: dark, stars: stars, variant: variant)))),
          if (child != null) child!,
        ]),
      ),
    );
  }
}

class _Star {
  const _Star(this.dx, this.dy, this.radius, this.alpha, this.sparkle);
  final double dx, dy, radius, alpha;
  final bool sparkle;
}

class _CosmicPainter extends CustomPainter {
  _CosmicPainter(
      {required this.dark, required this.stars, required this.variant});

  final bool dark;
  final bool stars;
  final CompanionBackdropVariant variant;

  static final List<_Star> _warmStars = _generate(11, 54);
  static final List<_Star> _coolStars = _generate(29, 78);

  static List<_Star> _generate(int seed, int count) {
    final random = math.Random(seed);
    return List<_Star>.generate(count, (_) {
      final sparkle = random.nextDouble() > .88;
      return _Star(
          random.nextDouble(),
          random.nextDouble(),
          sparkle ? 1.5 + random.nextDouble() * 1.2 : .5 + random.nextDouble(),
          .25 + random.nextDouble() * .55,
          sparkle);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    _nebula(canvas, size);
    if (stars) _starfield(canvas, size);
  }

  void _nebula(Canvas canvas, Size size) {
    void halo(Offset center, double radius, Color color) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
                    colors: [color, color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: center, radius: radius)));
    }

    final hero = variant == CompanionBackdropVariant.hero;
    final strength = dark ? 1.0 : .62;
    final pinkAlpha = (hero ? .30 : .20) * strength;
    final violetAlpha = (hero ? .34 : .26) * strength;
    final mintAlpha = (hero ? .18 : .14) * strength;
    halo(Offset(size.width * .88, size.height * .08),
        size.shortestSide * (hero ? .95 : .8),
        CompanionTheme.pink.withValues(alpha: pinkAlpha));
    halo(Offset(size.width * .08, size.height * .92),
        size.shortestSide * .85,
        CompanionTheme.violet.withValues(alpha: violetAlpha));
    halo(Offset(size.width * .86, size.height * .96),
        size.shortestSide * .62,
        CompanionTheme.mint.withValues(alpha: mintAlpha));
    if (hero) {
      halo(Offset(size.width * .55, size.height * .5),
          size.shortestSide * .5,
          CompanionTheme.cyan.withValues(alpha: .10 * strength));
    }
  }

  void _starfield(Canvas canvas, Size size) {
    final warm = dark ? CompanionTheme.pink : CompanionTheme.violet;
    final cool = dark ? Colors.white : CompanionTheme.violetDeep;
    for (final bucket in [_warmStars, _coolStars]) {
      final color = bucket == _warmStars ? warm : cool;
      for (final star in bucket) {
        final center = Offset(star.dx * size.width, star.dy * size.height);
        final alpha = star.alpha * (dark ? 1.0 : .55);
        if (star.sparkle) {
          _spark(canvas, center, star.radius * 2.4,
              color.withValues(alpha: alpha * .8));
        } else {
          canvas.drawCircle(center, star.radius,
              Paint()..color = color.withValues(alpha: alpha * .7));
        }
      }
    }
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx + r * .18, c.dy - r * .18, c.dx + r, c.dy)
          ..quadraticBezierTo(c.dx + r * .18, c.dy + r * .18, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx - r * .18, c.dy + r * .18, c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx - r * .18, c.dy - r * .18, c.dx, c.dy - r)
          ..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CosmicPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.stars != stars ||
      oldDelegate.variant != variant;
}
