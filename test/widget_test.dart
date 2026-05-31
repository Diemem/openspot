import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openspot/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenSpotApp());

    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}