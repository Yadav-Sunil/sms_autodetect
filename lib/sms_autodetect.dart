library sms_autodetect;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    if (method.method == 'smscode') {
      var arguments = method.arguments;
      var encode = jsonEncode(arguments);
      var decode = jsonDecode(encode);
      _code.add({"code": decode["code"], "msg": decode["msg"]});
    }
  }

  Stream<Map<String, String>> get code => _code.stream;

  Future<String?> get hint async {
    final String? hint = await _channel.invokeMethod('requestPhoneHint');
    return hint;
  }

  Future<void> get listenForCode async {
    await _channel.invokeMethod('listenForCode');
  }

  Future<void> unregisterListener() async {
    await _channel.invokeMethod('unregisterListener');
  }

  Future<String> get getAppSignature async {
    final String? appSignature = await _channel.invokeMethod('getAppSignature');
    return appSignature ?? '';
  }
}

mixin SMSAutoFill {
  final SmsAutoDetect _autoFill = SmsAutoDetect();
  StreamSubscription? _subscription;

  void listenForCode() {
    _subscription = _autoFill.code.listen((data) {
      var code = data["code"] ?? "";
      var msg = data["msg"] ?? "";
      codeUpdated(code, msg);
    });
    _autoFill.listenForCode;
  }

  Future<void> cancel() async {
    return _subscription?.cancel();
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
    _focusNode.addListener(() async {
      if (_focusNode.hasFocus && !_hintShown) {
        _hintShown = true;
        scheduleMicrotask(() {
          _askPhoneHint();
        });
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          suffixIcon: Platform.isAndroid
              ? IconButton(
                  icon: Icon(Icons.phonelink_setup),
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
    _controller.value = TextEditingValue(text: hint ?? '');
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
