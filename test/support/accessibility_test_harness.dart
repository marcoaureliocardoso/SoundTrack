import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const accessibilityTextScales = <double>[1, 1.5, 2];
const accessibilityViewports = <Size>[Size(320, 480), Size(480, 320)];

Future<void> pumpAccessibleApp(
  WidgetTester tester, {
  required Widget home,
  required Size viewport,
  required double textScale,
}) async {
  tester.view
    ..physicalSize = viewport
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pump();
}

bool intersects(WidgetTester tester, Finder first, Finder second) =>
    tester.getRect(first).overlaps(tester.getRect(second));
