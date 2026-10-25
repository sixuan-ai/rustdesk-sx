import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/companion_theme.dart';
import 'package:flutter_hbb/desktop/widgets/companion_connection_surface.dart';
import 'package:flutter_hbb/desktop/widgets/companion_peer_widgets.dart';

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
  testWidgets('Brand remains readable in a narrow sidebar', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: const SizedBox(width: 240, child: CompanionBrand()),
    ))));
    expect(find.text('RustDesk SX'), findsOneWidget);
    expect(find.text('思玄二次开发版'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Icon-only device tabs keep their accessible selected label',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CompanionPeerTabLabel(
      icon: Icons.star,
      label: '收藏夹',
      selected: true,
      showLabel: false,
      labelWidth: 112,
      color: Colors.purple,
    ))));
    expect(find.bySemanticsLabel('收藏夹'), findsOneWidget);
    expect(find.text('收藏夹'), findsNothing);
    expect(
        tester
            .getSemantics(find.byType(CompanionPeerTabLabel))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('Empty device guidance scrolls in a short large-text window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: const CompanionPeerEmptyState(
          icon: Icons.star, title: '收藏夹', message: '收藏常用设备后，可在这里快速连接。'),
    ))));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('收藏常用设备后，可在这里快速连接。').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login prompt keeps the empty-state layout and its action',
      (tester) async {
    var loggedIn = false;
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CompanionPeerEmptyState(
      icon: Icons.menu_book_rounded,
      title: '地址簿',
      action: FilledButton.icon(
          onPressed: () => loggedIn = true,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('登录')),
    ))));
    expect(find.text('地址簿'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.tap(find.text('登录'));
    expect(loggedIn, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'Network error detail sits above the retry action in '
        '${dark ? 'dark' : 'light'} theme', (tester) async {
      var retried = false;
      final theme = CompanionTheme.apply(
          ThemeData(brightness: dark ? Brightness.dark : Brightness.light));
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: CompanionPeerEmptyState(
            icon: Icons.cloud_off_rounded,
            title: '网络错误',
            message: '请检查网络连接后重试。',
            detail: const SelectableText('Failed to load the address book'),
            action: FilledButton.icon(
                onPressed: () => retried = true,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试')),
          ))));
      expect(find.text('Failed to load the address book'), findsOneWidget);
      expect(
          tester.getCenter(find.text('Failed to load the address book')).dy,
          lessThan(tester.getCenter(find.text('重试')).dy));
      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
        'Inline error banner keeps retry and close reachable in a narrow '
        '${dark ? 'dark' : 'light'} window', (tester) async {
      var retried = false, closed = false;
      final theme = CompanionTheme.apply(
          ThemeData(brightness: dark ? Brightness.dark : Brightness.light));
      await tester.binding.setSurfaceSize(const Size(300, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topCenter,
                  child: CompanionErrorBanner(
                    message: '获取地址簿失败，请检查网络连接后重试。',
                    retryLabel: '重试',
                    onRetry: () => retried = true,
                    closeLabel: '关闭',
                    onClose: () => closed = true,
                  )))));
      expect(find.text('获取地址簿失败，请检查网络连接后重试。'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.tap(find.byTooltip('关闭'));
      expect(retried, isTrue);
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
