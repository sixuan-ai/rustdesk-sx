import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/companion_theme.dart';
import 'package:flutter_hbb/desktop/widgets/companion_connection_surface.dart';

void main() {
  test('Chinese is the default and explicit language choices are respected',
      () {
    expect(CompanionTheme.localeForLanguage(''), const Locale('zh', 'CN'));
    expect(
        CompanionTheme.localeForLanguage('default'), const Locale('zh', 'CN'));
    expect(CompanionTheme.localeForLanguage('en'), const Locale('en'));
    expect(CompanionTheme.localeForLanguage('zh-tw'), const Locale('zh', 'TW'));
  });

  for (final dark in [false, true]) {
    testWidgets(
        'Connection form remains usable in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      final theme = CompanionTheme.apply(
          ThemeData(brightness: dark ? Brightness.dark : Brightness.light));
      for (final width in [320.0, 520.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 600));
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(
              body: CompanionConnectionSurface(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('控制远程桌面'),
                  const TextField(
                      decoration: InputDecoration(hintText: '输入对方 ID')),
                  ElevatedButton(onPressed: () {}, child: const Text('连接')),
                ]),
              )),
            )));
        await tester.enterText(find.byType(TextField), '100.89.0.1');
        await tester.tap(find.text('连接'));
        await tester.pump();
        expect(find.text('100.89.0.1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final text = tester.element(find.text('控制远程桌面'));
        expect(DefaultTextStyle.of(text).style.fontFamily, 'MiSans');
      }
      await tester.binding.setSurfaceSize(null);
    });
  }
}
