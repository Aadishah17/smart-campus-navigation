import 'package:flutter_test/flutter_test.dart';
import 'package:smart_campus_flutter/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());
    expect(find.text('Parul University Navigator'), findsOneWidget);
    expect(find.text('Campus-first live wayfinding'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Parul University Navigator'), findsWidgets);
  });
}
