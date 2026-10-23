import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palette derived from the supplied AAA references, with opaque control surfaces.
class CompanionTheme {
  static const ink = Color(0xFF29223D);
  static const violet = Color(0xFF7650BC);
  static const pink = Color(0xFFF3A5E4);
  static const lilac = Color(0xFFE7DBFA);
  static const mint = Color(0xFFBAEEE8);
  static const midnight = Color(0xFF171329);

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

  static ThemeData apply(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final text = dark ? const Color(0xFFF4EEFF) : ink;
    final muted = dark ? const Color(0xFFBEB1D0) : const Color(0xFF766A86);
    final surface = dark ? const Color(0xFF27203B) : Colors.white;
    final edge = dark ? const Color(0xFF514363) : const Color(0xFFDFD4EC);
    final primary = dark ? const Color(0xFFD5B7FC) : violet;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final outline = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: edge));
    return base.copyWith(
      scaffoldBackgroundColor: dark ? midnight : const Color(0xFFFCFAFF),
      canvasColor: surface,
      cardColor: dark ? const Color(0xFF302743) : const Color(0xFFF3EDF9),
      dividerColor: edge,
      hintColor: muted,
      hoverColor: primary.withValues(alpha: .09),
      textTheme: base.textTheme
          .apply(fontFamily: 'MiSans', bodyColor: text, displayColor: text),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'MiSans'),
      colorScheme: base.colorScheme.copyWith(
          primary: primary,
          secondary: primary,
          surface: surface,
          onPrimary: dark ? midnight : Colors.white,
          onSurface: text,
          background: dark ? const Color(0xFF211A33) : const Color(0xFFF2ECF8)),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: surface),
      popupMenuTheme: base.popupMenuTheme.copyWith(color: surface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: surface,
        filled: true,
        border: outline,
        hintStyle: TextStyle(color: muted, fontFamily: 'MiSans'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: dark ? midnight : Colors.white,
              elevation: 0,
              shape: shape,
              textStyle: const TextStyle(
                  fontFamily: 'MiSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              backgroundColor: surface,
              foregroundColor: text,
              side: BorderSide(color: edge),
              shape: shape)),
      textButtonTheme: TextButtonThemeData(
          style: base.textButtonTheme.style?.copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled) ? muted : primary))),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: primary,
          selectionColor: primary.withValues(alpha: .25),
          selectionHandleColor: primary),
    );
  }
}
