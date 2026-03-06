import 'package:flutter_test/flutter_test.dart';
import 'package:smart_campus_flutter/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCampusApp());
    expect(find.text('Smart Campus Navigation'), findsOneWidget);
    expect(find.text('Live Integrated Maps'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Smart Campus Navigator'), findsOneWidget);
  });
}
