import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brick_breaker/main.dart';

void main() {
  testWidgets('starts with 3 lives and launches on tap', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone portrait
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BrickBreakerApp());

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.text('Tap to launch'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Tap to launch')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Tap to launch'), findsNothing);
  });

  testWidgets('keyboard controls work for desktop testing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800); // desktop window
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BrickBreakerApp());
    await tester.pump();

    final ballStart = tester.getCenter(find.text('Tap to launch'));
    expect(ballStart.dx, 640); // phone-sized frame centered on screen

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Tap to launch'), findsNothing);
  });
}
