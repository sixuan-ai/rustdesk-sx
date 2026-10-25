import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palette derived from the supplied AAA references, with opaque control surfaces.
class CompanionTheme {
  static const ink = Color(0xFF29223D);
  static const violet = Color(0xFF7650BC);
  static const violetDeep = Color(0xFF54348F);
  static const pink = Color(0xFFF3A5E4);
  static const lilac = Color(0xFFE7DBFA);
  static const mint = Color(0xFFBAEEE8);
  static const midnight = Color(0xFF171329);

  static const cosmicDeep = Color(0xFF120E22);
  static const cosmic = Color(0xFF1B1332);
  static const cosmicLift = Color(0xFF271D43);
  static const cream = Color(0xFFFFF8F2);
  static const peach = Color(0xFFF7C6B6);
  static const lemon = Color(0xFFF3E3A2);
  static const cyan = Color(0xFFA7E4EE);
  static const coral = Color(0xFFF28B82);
  static const mintDeep = Color(0xFF176B5D);

  static const double controlRadius = 14;
  static const double panelRadius = 24;
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Locale localeForLanguage(String saved) {
    final parts = (saved.isEmpty || saved == 'default' ? 'zh-CN' : saved)
        .replaceAll('_', '-')
        .split('-');
    return Locale(
        parts.first, parts.length > 1 ? parts[1].toUpperCase() : null);
  }

  static void registerFontLicense() {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        ['MiSans'],
        await rootBundle.loadString('assets/fonts/misans/LICENSE.txt'),
      );
    });
  }

  static LinearGradient shellGradient(bool dark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [cosmicDeep, cosmic, Color(0xFF241A44)]
          : const [
              Color(0xFFFBF3FB),
              Color(0xFFF4F0FE),
              Color(0xFFEDF8F4)
            ]);

  static LinearGradient sidebarGradient(bool dark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF2C1B47), Color(0xFF1D1638), Color(0xFF16132B)]
          : const [
              Color(0xFFFFF3F8),
              Color(0xFFF7EFFD),
              Color(0xFFEEF8F5)
            ]);

  static LinearGradient heroGradient(bool dark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF452A63), Color(0xFF2C2352), Color(0xFF1D2749)]
          : const [
              Color(0xFFFFF2F5),
              Color(0xFFF7EDFD),
              Color(0xFFEBF8F4)
            ]);

  static LinearGradient primaryGradient(bool dark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFFC79BF5), Color(0xFFE48BE2)]
          : const [violet, Color(0xFFB468D2)]);

  static List<BoxShadow> glow(Color color,
          {double blur = 30, double y = 10, double alpha = .28}) =>
      [
        BoxShadow(
            color: color.withValues(alpha: alpha),
            blurRadius: blur,
            spreadRadius: -2,
            offset: Offset(0, y))
      ];

  /// Translucent panel used for grouped identity and helper content.
  static BoxDecoration panel(BuildContext context,
      {double radius = panelRadius,
      bool withGlow = false,
      Color? tint,
      Color? border}) {
    final dark = isDark(context);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: border ??
              (dark
                  ? Colors.white.withValues(alpha: .10)
                  : Colors.white.withValues(alpha: .92))),
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  (tint ?? const Color(0xFF332650)).withValues(alpha: .86),
                  (tint ?? const Color(0xFF221B3D)).withValues(alpha: .92)
                ]
              : [
                  tint ?? const Color(0xFFFFFFFF),
                  tint ?? const Color(0xFFFBF2FA)
                ]),
      boxShadow: [
        if (withGlow) ...glow(violet, alpha: dark ? .36 : .14, blur: 34),
        BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .20 : .05),
            blurRadius: 18,
            offset: const Offset(0, 8)),
      ],
    );
  }

  static ThemeData apply(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final text = dark ? const Color(0xFFF4EEFF) : ink;
    final muted = dark ? const Color(0xFFBEB1D0) : const Color(0xFF766A86);
    final surface = dark ? const Color(0xFF241B3C) : const Color(0xFFFFFCF9);
    final edge = dark
        ? Colors.white.withValues(alpha: .10)
        : const Color(0xFFEADFF3);
    final primary = dark ? const Color(0xFFD8B6FF) : violet;
    final outline = OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide(color: edge));
    final pillShape = const StadiumBorder();
    return base.copyWith(
      scaffoldBackgroundColor: dark ? cosmicDeep : const Color(0xFFFBF6FC),
      canvasColor: surface,
      cardColor: dark ? const Color(0xFF2A2144) : const Color(0xFFFBF1F8),
      dividerColor: edge,
      hintColor: muted,
      hoverColor: primary.withValues(alpha: .09),
      shadowColor: Colors.black.withValues(alpha: dark ? .4 : .12),
      textTheme: base.textTheme
          .apply(fontFamily: 'MiSans', bodyColor: text, displayColor: text),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'MiSans'),
      colorScheme: base.colorScheme.copyWith(
          primary: primary,
          secondary: dark ? pink : const Color(0xFFB468D2),
          tertiary: mint,
          surface: surface,
          onPrimary: dark ? cosmicDeep : Colors.white,
          onSurface: text,
          background: dark ? const Color(0xFF1D1535) : const Color(0xFFF6F0FA)),
      dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: surface,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: .35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(panelRadius),
              side: BorderSide(color: edge))),
      popupMenuTheme: base.popupMenuTheme.copyWith(
          color: surface,
          elevation: 18,
          shadowColor: Colors.black.withValues(alpha: .3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: edge))),
      cardTheme: base.cardTheme.copyWith(
          color: surface,
          elevation: 0,
          margin: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: edge))),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: dark
            ? Colors.white.withValues(alpha: .06)
            : Colors.white.withValues(alpha: .82),
        filled: true,
        border: outline,
        hintStyle: TextStyle(color: muted, fontFamily: 'MiSans'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: dark ? cosmicDeep : Colors.white,
              shadowColor: primary.withValues(alpha: .5),
              elevation: 0,
              shape: pillShape,
              textStyle: const TextStyle(
                  fontFamily: 'MiSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: text,
              side: BorderSide(color: edge),
              shape: pillShape,
              textStyle: const TextStyle(
                  fontFamily: 'MiSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500))),
      textButtonTheme: TextButtonThemeData(
          style: base.textButtonTheme.style?.copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled) ? muted : primary),
              shape: WidgetStatePropertyAll(pillShape))),
      chipTheme: base.chipTheme.copyWith(
          backgroundColor: primary.withValues(alpha: .10),
          selectedColor: primary.withValues(alpha: .20),
          labelStyle: TextStyle(
              fontFamily: 'MiSans', fontSize: 12, color: primary),
          secondaryLabelStyle: TextStyle(
              fontFamily: 'MiSans', fontSize: 12, color: text),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
      tooltipTheme: base.tooltipTheme.copyWith(
          waitDuration: const Duration(milliseconds: 450),
          decoration: BoxDecoration(
              color: dark ? const Color(0xF22B2147) : const Color(0xF229223D),
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontFamily: 'MiSans', fontSize: 12, color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      switchTheme: base.switchTheme.copyWith(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primary : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? primary.withValues(alpha: .38)
                  : null)),
      checkboxTheme: base.checkboxTheme.copyWith(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primary : null),
          checkColor: WidgetStatePropertyAll(
              dark ? cosmicDeep : Colors.white),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5))),
      dividerTheme: DividerThemeData(color: edge, thickness: .7, space: .7),
      scrollbarTheme: base.scrollbarTheme.copyWith(
          thickness: const WidgetStatePropertyAll(6),
          radius: const Radius.circular(6),
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              primary.withValues(
                  alpha: states.contains(WidgetState.dragged) ? .55 : .30))),
      progressIndicatorTheme:
          base.progressIndicatorTheme.copyWith(color: primary),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: primary,
          selectionColor: primary.withValues(alpha: .25),
          selectionHandleColor: primary),
    );
  }
}
