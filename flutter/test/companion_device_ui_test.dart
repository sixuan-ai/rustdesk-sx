import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/companion_theme.dart';
import 'package:flutter_hbb/desktop/widgets/companion_device_widgets.dart';

void main() {
  testWidgets(
      'Device identity and menu remain usable with long names and large text',
      (tester) async {
    var opened = false;
    for (final dark in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        theme: CompanionTheme.apply(
            ThemeData(brightness: dark ? Brightness.dark : Brightness.light)),
        home: Scaffold(
            body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 220,
                height: 140,
                child: CompanionDeviceCard(
                  title: '工作站与很长的设备别名',
                  id: '100.64.0.2',
                  host: 'user@workstation',
                  note: '外接显示器',
                  online: dark,
                  statusLabel: dark ? '在线' : '未确认在线',
                  platform: const Icon(Icons.computer, color: Colors.white),
                  action: IconButton(
                      tooltip: '更多',
                      onPressed: () => opened = true,
                      icon: const Icon(Icons.more_vert)),
                ),
              )),
        )),
      ));
      expect(find.text('工作站与很长的设备别名'), findsOneWidget);
      expect(find.text('100.64.0.2'), findsOneWidget);
      await tester.tap(find.byTooltip('更多'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Search can be cleared without closing the field, and no-results offers recovery',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changed = '';
    var closed = false;
    var recovered = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      CompanionDeviceSearch(
          controller: controller,
          onChanged: (value) => changed = value,
          onClose: () => closed = true,
          hint: '搜索设备',
          clearLabel: '清除搜索',
          closeLabel: '关闭'),
      Expanded(
          child: CompanionNoSearchResults(
              query: '不存在的设备',
              title: '没有匹配的设备',
              clearLabel: '清除搜索',
              onClear: () => recovered = true)),
    ]))));
    await tester.enterText(find.byType(TextField), '不存在的设备');
    await tester.pump();
    expect(changed, '不存在的设备');
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changed, isEmpty);
    expect(closed, isFalse);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '清除搜索'));
    expect(recovered, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Narrow service status names its source and explains direct IP separately',
      (tester) async {
    const detail = 'ID 服务器状态不代表 IP 直连状态';
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 220,
      child: CompanionServiceStatusLabel(
          label: 'ID 服务器', message: '未就绪', explanation: detail),
    ))));
    expect(find.text('ID 服务器  未就绪', findRichText: true), findsOneWidget);
    await tester.longPress(find.byType(CompanionServiceStatusLabel));
    await tester.pumpAndSettle();
    expect(find.text('ID 服务器: 未就绪\n$detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
