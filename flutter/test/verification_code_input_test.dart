import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';

void main() {
  testWidgets('typing a code keeps focus when the underlying login rebuilds',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    late StateSetter rebuildLogin;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          StatefulBuilder(builder: (context, setState) {
            rebuildLogin = setState;
            return CustomAlertDialog(content: const Text('Account login'));
          }),
          CustomAlertDialog(
            title: const Text('Verification code'),
            content: DialogVerificationCodeField(
              controller: controller,
              title: 'Code',
              onChanged: (_, __) => rebuildLogin(() {}),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 70));
    for (var length = 1; length <= 6; length++) {
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('123456'.substring(0, length));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(controller.text, '123456'.substring(0, length));
      expect(controller.selection, TextSelection.collapsed(offset: length));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue);
    }
    tester.testTextInput.enterText('654321');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(controller.text, '654321');
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('dialog keyboard submit cancel and traversal still work',
      (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var submitted = 0;
    var cancelled = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomAlertDialog(
          onSubmit: () => submitted++,
          onCancel: () => cancelled++,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(focusNode: first, autofocus: true),
            TextField(focusNode: second),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submitted, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
