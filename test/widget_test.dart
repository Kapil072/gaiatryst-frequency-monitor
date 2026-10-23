import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaiatryst_schumann_sync/main.dart';

void main() {
  testWidgets('App builds and shows the header', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('GAIATRYST SYNOPSIS SCHUMANN RESONANCE LINK'),
        findsOneWidget);
    expect(find.text('Average Data'), findsOneWidget);

    // Unmount and let the delayed first fetch fire against a disposed page.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
