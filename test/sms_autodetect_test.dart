import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_autodetect/sms_autodetect.dart';

class _SmsAutoFillHarness with SMSAutoFill {
  final List<Map<String, String>> updates = <Map<String, String>>[];

  @override
  void codeUpdated(String code, String msg) {
    updates.add(<String, String>{'code': code, 'msg': msg});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsAutoDetect Tests', () {
    const MethodChannel channel = MethodChannel('sms_autodetect');
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      log.clear();
      debugDefaultTargetPlatformOverride = null;
    });

    test('Stream receives code when smscode method is called', () async {
      final SmsAutoDetect smsAutoDetect = SmsAutoDetect();

      // We can't directly call _didReceive since is private, but we can simulate the native side calling the channel.
      // However, since we are mocking the handler, we are the ones "handling" calls TO native.
      // We actually want to test the handler that DART registers to receive FROM native.

      // SmsAutoDetect registers a handler in its constructor.
      // We need to simulate the platform invoking that handler.
      // To do this using `handlePlatformMessage`, we need to encode the call.

      final Map<String, dynamic> arguments = {
        "code": "123456",
        "msg": "Your code is 123456"
      };

      // Create expectations
      expectLater(smsAutoDetect.code,
          emits({"code": "123456", "msg": "Your code is 123456"}));

      // Simulate platform message
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'sms_autodetect',
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('smscode', arguments)),
        (ByteData? data) {},
      );
    });

    test('Stream receives code when smscode payload is JSON', () async {
      final SmsAutoDetect smsAutoDetect = SmsAutoDetect();

      expectLater(
        smsAutoDetect.code,
        emits({"code": "654321", "msg": "Your code is 654321"}),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'sms_autodetect',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(
            'smscode',
            '{"code":"654321","msg":"Your code is 654321"}',
          ),
        ),
        (ByteData? data) {},
      );
    });

    test('SMSAutoFill mixin starts native listener', () async {
      final _SmsAutoFillHarness harness = _SmsAutoFillHarness();
      addTearDown(harness.cancel);

      harness.listenForCode(smsCodeRegexPattern: r'\d{6}');
      await Future<void>.delayed(Duration.zero);

      expect(log, hasLength(1));
      expect(log.single.method, 'listenForCode');
      expect(
        log.single.arguments,
        <String, String>{'smsCodeRegexPattern': r'\d{6}'},
      );
    });
  });
}
