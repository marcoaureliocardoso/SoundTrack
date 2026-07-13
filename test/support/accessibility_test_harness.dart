import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const accessibilityTextScales = <double>[1, 1.5, 2];
const accessibilityViewports = <Size>[Size(320, 480), Size(480, 320)];

typedef AccessibilityTestCase = ({Size viewport, double textScale});

final accessibilityTestCases = <AccessibilityTestCase>[
  for (final viewport in accessibilityViewports)
    for (final textScale in accessibilityTextScales)
      (viewport: viewport, textScale: textScale),
];

String accessibilityTestCaseLabel(AccessibilityTestCase testCase) {
  final orientation = testCase.viewport.width < testCase.viewport.height
      ? 'portrait'
      : 'landscape';
  return '${(testCase.textScale * 100).round()}% $orientation';
}

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
