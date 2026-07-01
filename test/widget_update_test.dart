import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_autodetect/sms_autodetect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PinCodeTextField updates controller when parent rebuilds',
      (WidgetTester tester) async {
    final TextEditingController controller1 =
        TextEditingController(text: '1234');
    final TextEditingController controller2 =
        TextEditingController(text: '5678');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (_) {},
                controller: controller1,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('1234'),
        findsOneWidget); // The hidden TextField contains this text.
    // Actually PinCodeTextField uses the controller to drive state.

    // Let's rely on checking if the field accepts input from the NEW controller.

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (_) {},
                controller: controller2,
              );
            },
          ),
        ),
      ),
    );

    // If didUpdateWidget is missing, the internal _textEditingController might still be controller1,
    // or at least checking the widget state might reveal inconsistencies.
    // The most direct check: The widget should now be listening to controller2.

    controller2.text = "9999";
    await tester.pump();

    // We can't easily peek into the state private controller, but we can check if the UI reflects "9999".
    // The cells are generated based on the controller text.
    // "9" should appear 4 times if we assume not obscured for this test (default is obscureText=false).

    expect(find.text('9'), findsNWidgets(4));
  });

  testWidgets('PhoneFieldHint removes stale focus listeners on rebuild',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('sms_autodetect'),
        null,
      );
    });

    const MethodChannel channel = MethodChannel('sms_autodetect');
    var hintRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'requestPhoneHint') {
        hintRequests += 1;
        return '555000$hintRequests';
      }
      return null;
    });

    final TextEditingController controller1 = TextEditingController();
    final TextEditingController controller2 = TextEditingController();
    final FocusNode focusNode1 = FocusNode();
    final FocusNode focusNode2 = FocusNode();
    addTearDown(controller1.dispose);
    addTearDown(controller2.dispose);
    addTearDown(focusNode1.dispose);
    addTearDown(focusNode2.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneFieldHint(
            controller: controller1,
            focusNode: focusNode1,
          ),
        ),
      ),
    );

    focusNode1.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(controller1.text, '5550001');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneFieldHint(
            controller: controller2,
            focusNode: focusNode2,
          ),
        ),
      ),
    );

    focusNode1.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(controller2.text, isEmpty);

    focusNode2.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(controller2.text, '5550002');

    debugDefaultTargetPlatformOverride = null;
  });
}
