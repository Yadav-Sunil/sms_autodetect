import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_autodetect/sms_autodetect.dart';

void main() {
  testWidgets('PinCodeTextField renders with Builder for context',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (value) {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(PinCodeTextField), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // The hidden text field
  });

  testWidgets('PinCodeTextField accepts input', (WidgetTester tester) async {
    String currentValue = "";
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (value) {
                  currentValue = value;
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), "1234");
    await tester.pump();

    expect(currentValue, "1234");
  });
}
