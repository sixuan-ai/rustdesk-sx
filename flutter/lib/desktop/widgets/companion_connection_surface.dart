import 'package:flutter/material.dart';
import '../../common/companion_theme.dart';
import '../../common/widgets/companion_backdrop.dart';

class CompanionBrand extends StatelessWidget {
  const CompanionBrand({super.key});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                gradient: CompanionTheme.primaryGradient(
                    CompanionTheme.isDark(context)),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .28), width: .8),
                boxShadow: CompanionTheme.glow(CompanionTheme.violet,
                    blur: 20, y: 6, alpha: .35)),
            child: const Icon(Icons.desktop_windows_rounded,
                color: Colors.white, size: 21)),
        const SizedBox(width: 11),
        Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Flexible(
                    child: Text('RustDesk SX',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2))),
                const SizedBox(width: 5),
                Icon(Icons.auto_awesome_rounded,
                    size: 13, color: CompanionTheme.pink.withValues(alpha: .9)),
              ]),
              const SizedBox(height: 3),
              Text('思玄二次开发版',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: .8,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: .7))),
            ])),
      ]));
}

/// Artwork has no hit targets; the existing connection form owns all input.
class CompanionConnectionSurface extends StatelessWidget {
  final Widget child;
  const CompanionConnectionSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = CompanionTheme.isDark(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .92)),
          boxShadow: [
            ...CompanionTheme.glow(CompanionTheme.violet,
                blur: 44, y: 16, alpha: dark ? .34 : .14),
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .24 : .06),
                blurRadius: 24,
                offset: const Offset(0, 10)),
          ]),
      child: CompanionBackdrop(
        variant: CompanionBackdropVariant.hero,
        child: LayoutBuilder(
            builder: (context, constraints) => Row(children: [
                  Flexible(flex: 3, child: child),
                  if (constraints.maxWidth >= 500)
                    const Expanded(
                        flex: 2,
                        child: ExcludeSemantics(
                            child: IgnorePointer(
                                child: SizedBox(
                                    height: 224,
                                    child: CustomPaint(
                                        painter: _CompanionPainter()))))),
                ])),
      ),
    );
  }
}

/// Original vector artwork with two lights on a floating desktop companion.
class _CompanionPainter extends CustomPainter {
  const _CompanionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 4);
    canvas.scale((size.width / 200).clamp(.4, 1.15));

    canvas.drawCircle(
        const Offset(0, 4),
        112,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x77F5A8E7), Color(0x22D6B4F5), Color(0x00EAC4F5)],
                  stops: [0.0, .62, 1.0])
              .createShader(const Rect.fromLTWH(-116, -106, 232, 232)));
    canvas.drawCircle(
        const Offset(0, 4),
        86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x33FFFFFF));
    canvas.drawOval(const Rect.fromLTWH(-70, 76, 140, 18),
        Paint()..color = const Color(0x337650BC));

    final body = Path()
      ..moveTo(-68, 10)
      ..cubicTo(-68, -26, -57, -60, -30, -52)
      ..cubicTo(-10, -45, 15, -56, 37, -54)
      ..cubicTo(67, -53, 77, -12, 72, 23)
      ..cubicTo(68, 58, 40, 62, 1, 62)
      ..cubicTo(-42, 62, -69, 50, -68, 10)
      ..close();
    canvas.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFD8F5),
                Color(0xFFED95E3),
                Color(0xFFB5A2F3)
              ]).createShader(const Rect.fromLTWH(-70, -55, 145, 120)));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xAAFFFFFF));

    canvas.drawOval(const Rect.fromLTWH(-52, 18, 26, 12),
        Paint()..color = const Color(0x33E2559B));
    canvas.drawOval(const Rect.fromLTWH(26, 18, 26, 12),
        Paint()..color = const Color(0x33E2559B));
    canvas.drawOval(const Rect.fromLTWH(-44, -38, 34, 20),
        Paint()..color = const Color(0x40FFFFFF));

    for (final x in [-18.0, 14.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -7, 8, 21), const Radius.circular(4)),
          Paint()..color = const Color(0xFF8150A9));
      canvas.drawCircle(
          Offset(x + 2.4, -2), 1.6, Paint()..color = const Color(0xCCFFFFFF));
    }
    canvas.drawPath(
        Path()
          ..moveTo(-8, 25)
          ..quadraticBezierTo(2, 32, 12, 25),
        Paint()
          ..color = const Color(0xFF9C61B2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);

    _spark(canvas, const Offset(-68, -65), 10, const Color(0xFF82CFC8));
    _spark(canvas, const Offset(67, -70), 7, const Color(0xFFD0A1EA));
    _spark(canvas, const Offset(84, 50), 9, const Color(0xFFE0B65A));
    _spark(canvas, const Offset(-38, 72), 5, const Color(0xB3FFFFFF));
    canvas.drawCircle(
        const Offset(-84, 37), 4, Paint()..color = CompanionTheme.mint);
    canvas.drawCircle(
        const Offset(49, -85), 3, Paint()..color = CompanionTheme.pink);
    canvas.drawCircle(
        const Offset(72, 12), 2.2, Paint()..color = CompanionTheme.cyan);
    canvas.restore();
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx + 2, c.dy - 2, c.dx + r, c.dy)
          ..quadraticBezierTo(c.dx + 2, c.dy + 2, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx - 2, c.dy + 2, c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx - 2, c.dy - 2, c.dx, c.dy - r)
          ..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CompanionPainter oldDelegate) => false;
}
