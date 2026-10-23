import 'package:flutter/material.dart';
import '../../common/companion_theme.dart';

class CompanionBrand extends StatelessWidget {
  const CompanionBrand({super.key});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [CompanionTheme.violet, Color(0xFFB786D8)]),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.desktop_windows_rounded,
                color: Colors.white, size: 21)),
        const SizedBox(width: 10),
        const Text('RustDesk',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
      ]));
}

/// Artwork has no hit targets; the existing connection form owns all input.
class CompanionConnectionSurface extends StatelessWidget {
  final Widget child;
  const CompanionConnectionSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: dark ? const Color(0xFF514363) : const Color(0xFFE8DDF0)),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF38234F), Color(0xFF252744)]
                  : const [
                      Color(0xFFF7E5F4),
                      Color(0xFFF0E9FC),
                      Color(0xFFE5F5F1)
                    ])),
      child: LayoutBuilder(
          builder: (context, constraints) => Row(children: [
                Flexible(flex: 3, child: child),
                if (constraints.maxWidth >= 500)
                  const Expanded(
                      flex: 2,
                      child: ExcludeSemantics(
                          child: IgnorePointer(
                              child: SizedBox(
                                  height: 212,
                                  child: CustomPaint(
                                      painter: _CompanionPainter()))))),
              ])),
    );
  }
}

/// Original vector artwork with two lights on a floating desktop companion.
class _CompanionPainter extends CustomPainter {
  const _CompanionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale((size.width / 200).clamp(.4, 1.15));
    canvas.drawCircle(
        const Offset(0, 4),
        108,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x66F5A8E7), Color(0x00EAC4F5)])
              .createShader(const Rect.fromLTWH(-110, -100, 220, 220)));
    canvas.drawOval(const Rect.fromLTWH(-62, 70, 124, 16),
        Paint()..color = const Color(0x227650BC));
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
                Color(0xFFFFD1F3),
                Color(0xFFED95E3),
                Color(0xFFB5A2F3)
              ]).createShader(const Rect.fromLTWH(-70, -55, 145, 120)));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x99FFFFFF));
    for (final x in [-18.0, 14.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -7, 8, 21), const Radius.circular(4)),
          Paint()..color = const Color(0xFF8150A9));
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
    _spark(canvas, const Offset(80, 48), 9, const Color(0xFFE0B65A));
    canvas.drawCircle(
        const Offset(-84, 37), 4, Paint()..color = CompanionTheme.mint);
    canvas.drawCircle(
        const Offset(49, -85), 3, Paint()..color = CompanionTheme.pink);
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
