library sms_autodetect;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autodetect/src/cursor_painter.dart';
import 'package:sms_autodetect/src/models/platform.dart';

part 'src/gradiented.dart';
part 'src/models/animation_type.dart';
part 'src/models/dialog_config.dart';
part 'src/models/haptic_feedback_type.dart';
part 'src/models/pin_theme.dart';
part 'src/pin_code_fields.dart';

class SmsAutoDetect {
  static SmsAutoDetect? _singleton;
  static const MethodChannel _channel = const MethodChannel('sms_autodetect');

  final StreamController<Map<String, String>> _code =
      StreamController.broadcast();

  factory SmsAutoDetect() => _singleton ??= SmsAutoDetect._();

  SmsAutoDetect._() {
    _channel.setMethodCallHandler(_didReceive);
  }

  Future<void> _didReceive(MethodCall method) async {
    if (method.method != 'smscode') {
      return;
    }

    final payload = _normalizeSmsPayload(method.arguments);
    if (payload != null) {
      _code.add(payload);
    }
  }

  Stream<Map<String, String>> get code => _code.stream;

  static bool get _supportsSmsAutoDetect =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _supportsAppSignature =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Map<String, String>? _normalizeSmsPayload(Object? arguments) {
    Object? payload = arguments;

    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } on FormatException {
        return null;
      }
    }

    if (payload is! Map) {
      return null;
    }

    return <String, String>{
      'code': payload['code']?.toString() ?? '',
      'msg': payload['msg']?.toString() ?? '',
    };
  }

  Future<String?> get hint async {
    if (_supportsSmsAutoDetect) {
      final String? hint = await _channel.invokeMethod('requestPhoneHint');
      return hint;
    }
    return null;
  }

  Future<void> listenForCode({String smsCodeRegexPattern = '\\d{4,6}'}) async {
    if (_supportsSmsAutoDetect) {
      await _channel.invokeMethod('listenForCode',
          <String, String>{'smsCodeRegexPattern': smsCodeRegexPattern});
    }
  }

  Future<void> unregisterListener() async {
    if (_supportsSmsAutoDetect) {
      await _channel.invokeMethod('unregisterListener');
    }
  }

  Future<String> get getAppSignature async {
    if (_supportsAppSignature) {
      final String? appSignature =
          await _channel.invokeMethod('getAppSignature');
      return appSignature ?? '';
    }
    return '';
  }
}

mixin SMSAutoFill {
  final SmsAutoDetect _autoFill = SmsAutoDetect();
  StreamSubscription? _subscription;

  void listenForCode({String smsCodeRegexPattern = '\\d{4,6}'}) {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _subscription = _autoFill.code.listen((data) {
      var code = data["code"] ?? "";
      var msg = data["msg"] ?? "";
      codeUpdated(code, msg);
    });
    unawaited(
      _autoFill.listenForCode(smsCodeRegexPattern: smsCodeRegexPattern),
    );
  }

  Future<void> cancel() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> unregisterListener() {
    return _autoFill.unregisterListener();
  }

  void codeUpdated(String code, String msg);
}

class PhoneFieldHint extends StatelessWidget {
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final InputDecoration? decoration;
  final TextField? child;

  const PhoneFieldHint({
    Key? key,
    this.child,
    this.controller,
    this.inputFormatters,
    this.decoration,
    this.autoFocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PhoneFieldHint(
        key: key,
        child: child,
        inputFormatters: inputFormatters,
        validator: null,
        controller: controller,
        decoration: decoration,
        autoFocus: autoFocus,
        focusNode: focusNode,
        isFormWidget: false);
  }
}

class _PhoneFieldHint extends StatefulWidget {
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator? validator;
  final bool isFormWidget;
  final InputDecoration? decoration;
  final TextField? child;

  const _PhoneFieldHint({
    Key? key,
    this.child,
    this.controller,
    this.inputFormatters,
    this.validator,
    this.isFormWidget = false,
    this.decoration,
    this.autoFocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PhoneFieldHintState();
  }
}

class _PhoneFieldHintState extends State<_PhoneFieldHint> {
  final SmsAutoDetect _autoFill = SmsAutoDetect();
  late TextEditingController _controller;
  late List<TextInputFormatter> _inputFormatters;
  late FocusNode _focusNode;
  bool _hintShown = false;
  bool _isUsingInternalController = false;
  bool _isUsingInternalFocusNode = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    _controller = widget.controller ??
        widget.child?.controller ??
        _createInternalController();
    _inputFormatters =
        widget.inputFormatters ?? widget.child?.inputFormatters ?? [];
    _focusNode = widget.focusNode ??
        widget.child?.focusNode ??
        _createInternalFocusNode();
    _focusNode.addListener(_handleFocusChanged);

    super.initState();
  }

  @override
  void didUpdateWidget(_PhoneFieldHint oldWidget) {
    _syncController();
    _syncFocusNode();

    if (widget.inputFormatters != oldWidget.inputFormatters) {
      _inputFormatters =
          widget.inputFormatters ?? widget.child?.inputFormatters ?? [];
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          suffixIcon: _isAndroid
              ? IconButton(
                  icon: const Icon(Icons.phonelink_setup),
                  onPressed: () async {
                    _hintShown = true;
                    await _askPhoneHint();
                  },
                )
              : null,
        );

    return widget.child ??
        _createField(widget.isFormWidget, decoration, widget.validator);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);

    if (_isUsingInternalController) {
      _controller.dispose();
    }

    if (_isUsingInternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Widget _createField(bool isFormWidget, InputDecoration decoration,
      FormFieldValidator? validator) {
    return isFormWidget
        ? _createTextFormField(decoration, validator)
        : _createTextField(decoration);
  }

  Widget _createTextField(InputDecoration decoration) {
    return TextField(
      autofocus: widget.autoFocus,
      focusNode: _focusNode,
      autofillHints: [AutofillHints.telephoneNumber],
      inputFormatters: _inputFormatters,
      decoration: decoration,
      controller: _controller,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _createTextFormField(
      InputDecoration decoration, FormFieldValidator? validator) {
    return TextFormField(
      validator: validator,
      autofocus: widget.autoFocus,
      focusNode: _focusNode,
      autofillHints: [AutofillHints.telephoneNumber],
      inputFormatters: _inputFormatters,
      decoration: decoration,
      controller: _controller,
      keyboardType: TextInputType.phone,
    );
  }

  Future<void> _askPhoneHint() async {
    String? hint = await _autoFill.hint;
    if (!mounted) {
      return;
    }
    _controller.value = TextEditingValue(text: hint ?? '');
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus && !_hintShown) {
      _hintShown = true;
      scheduleMicrotask(_askPhoneHint);
    }
  }

  void _syncController() {
    final oldController = _controller;
    final wasUsingInternalController = _isUsingInternalController;
    final providedController = widget.controller ?? widget.child?.controller;

    if (providedController == null) {
      if (wasUsingInternalController) {
        return;
      }
      _controller = _createInternalController();
    } else {
      if (!wasUsingInternalController &&
          identical(oldController, providedController)) {
        return;
      }
      _isUsingInternalController = false;
      _controller = providedController;
    }

    if (wasUsingInternalController) {
      oldController.dispose();
    }
    _hintShown = false;
  }

  void _syncFocusNode() {
    final oldFocusNode = _focusNode;
    final wasUsingInternalFocusNode = _isUsingInternalFocusNode;
    final providedFocusNode = widget.focusNode ?? widget.child?.focusNode;

    if (providedFocusNode == null) {
      if (wasUsingInternalFocusNode) {
        return;
      }
      _focusNode = _createInternalFocusNode();
    } else {
      if (!wasUsingInternalFocusNode &&
          identical(oldFocusNode, providedFocusNode)) {
        return;
      }
      _isUsingInternalFocusNode = false;
      _focusNode = providedFocusNode;
    }

    oldFocusNode.removeListener(_handleFocusChanged);
    if (wasUsingInternalFocusNode) {
      oldFocusNode.dispose();
    }
    _focusNode.addListener(_handleFocusChanged);
    _hintShown = false;
  }

  TextEditingController _createInternalController() {
    _isUsingInternalController = true;
    return TextEditingController(text: '');
  }

  FocusNode _createInternalFocusNode() {
    _isUsingInternalFocusNode = true;
    return FocusNode();
  }
}
