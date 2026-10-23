import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/wayland_text_input.dart';

void main() {
  Future<void> open(
      WidgetTester tester, Future<void> Function(String) send) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WaylandTextInput(
      sendText: send,
      onEditing: (_) {},
    ))));
    await tester.tap(find.text('中文输入'));
    await tester.pump();
  }

  testWidgets(
      'preedit is local; committed Chinese and multiline text send once',
      (tester) async {
    final sent = <String>[];
    await open(tester, (text) async {
      sent.add(text);
    });
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'zhongwen',
      selection: TextSelection.collapsed(offset: 8),
      composing: TextRange(start: 0, end: 8),
    ));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '发送到远端'))
            .onPressed,
        isNull);
    expect(sent, isEmpty);
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '中文输入\nWayland ✅',
      selection: TextSelection.collapsed(offset: 14),
    ));
    await tester.pump();
    await tester.tap(find.text('发送到远端'));
    await tester.pump();
    expect(sent, ['中文输入\nWayland ✅']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('failed send retains draft and allows retry', (tester) async {
    await open(tester, (_) async {
      throw StateError('disconnected');
    });
    await tester.enterText(find.byType(TextField), '保留草稿');
    await tester.pump();
    await tester.tap(find.text('发送到远端'));
    await tester.pump();
    expect(find.text('发送失败，请检查连接后重试'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '保留草稿');
  });

  testWidgets('collapse preserves draft without sending', (tester) async {
    final sent = <String>[];
    await open(tester, (text) async {
      sent.add(text);
    });
    await tester.enterText(find.byType(TextField), '尚未发送');
    await tester.tap(find.text('收起'));
    await tester.pump();
    await tester.tap(find.text('中文输入'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '尚未发送');
    expect(sent, isEmpty);
  });
}
