import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/widgets/glass_container.dart';

void main() {
  group('GlassContainer Widget Tests', () {
    testWidgets('renders child widget correctly', (WidgetTester tester) async {
      const childKey = Key('child_text');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Hello Glass', key: childKey),
            ),
          ),
        ),
      );

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.text('Hello Glass'), findsOneWidget);
    });

    testWidgets('applies custom padding and border radius', (WidgetTester tester) async {
      const padding = EdgeInsets.all(24.0);
      const borderRadius = 32.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: padding,
              borderRadius: borderRadius,
              child: Text('Test Padding & Radius'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Verify the decoration and padding
      final Container containerWidget = tester.widget(containerFinder.first);
      expect(containerWidget.padding, padding);

      final BoxDecoration? decoration = containerWidget.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.borderRadius, BorderRadius.circular(borderRadius));
    });
  });
}
