import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sms_autodetect/sms_autodetect.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        backgroundColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: HomePage(), // a random number, please don't call xD
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SMSAutoFill {
  final textEditingController = TextEditingController();
  String signature = "{{ app signature }}";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    SmsAutoDetect().unregisterListener();
    super.dispose();
  }

  @override
  void codeUpdated(String code, String msg) {
    textEditingController.text = code;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Otp Auto Detect'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PhoneFieldHint(
                autoFocus: true,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 2, color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 2, color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 2, color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  suffixIconConstraints: BoxConstraints(
                    minWidth: 45,
                    minHeight: 0,
                  ),
                ),
              ),
              Spacer(),
              PinCodeTextField(
                autoDisposeControllers: false,
                appContext: context,
                pastedTextStyle: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
                length: 6,
                obscureText: true,
                obscuringCharacter: '*',
                // if you are using obscuringCharacter remove obscuringWidget
                obscuringWidget: Icon(Icons.vpn_key_rounded),
                blinkWhenObscuring: true,
                animationType: AnimationType.fade,
                validator: (v) {
                  if (v!.length < 6) {
                    return "Please enter valid OTP";
                  } else {
                    return null;
                  }
                },
                pinTheme: PinTheme(
                  fieldOuterPadding: EdgeInsets.only(left: 8, right: 8),
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(5),
                  fieldHeight: 50,
                  fieldWidth: 45,
                  activeFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                  selectedColor: Colors.black54,
                  selectedFillColor: Colors.white,
                  inactiveColor: Colors.black54,
                  activeColor: Colors.black54,
                ),
                cursorColor: Colors.black,
                animationDuration: Duration(milliseconds: 300),
                enableActiveFill: true,
                autoDismissKeyboard: false,
                controller: textEditingController,
                keyboardType: TextInputType.number,
                mainAxisAlignment: MainAxisAlignment.center,
                boxShadows: [
                  BoxShadow(
                    offset: Offset(0, 1),
                    color: Colors.black12,
                    blurRadius: 5,
                  )
                ],
                onCompleted: (v) {
                  print("Completed");
                },
                onTap: () {
                  print("Pressed");
                },
                onChanged: (value) {
                  print(value);
                },
                beforeTextPaste: (text) {
                  print("Allowing to paste $text");
                  //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                  //but you can show anything you want here, like your pop up saying wrong paste format or etc
                  return true;
                },
              ),
              Spacer(),
              ElevatedButton(
                child: Text('Listen for sms code'),
                onPressed: () async {
                  await SmsAutoDetect().listenForCode;
                },
              ),
              ElevatedButton(
                child: Text('Set code to 123456'),
                onPressed: () async {
                  setState(() {
                    textEditingController.text = '123456';
                  });
                },
              ),
              SizedBox(height: 8.0),
              Divider(height: 1.0),
              SizedBox(height: 4.0),
              Text("App Signature : $signature"),
              SizedBox(height: 4.0),
              ElevatedButton(
                child: Text('Get app signature'),
                onPressed: () async {
                  signature = await SmsAutoDetect().getAppSignature;
                  setState(() {});
                },
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OtpCodeVerificationScreen(),
                    ),
                  );
                },
                child: Text("Test CodeAutoFill mixin"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class OtpCodeVerificationScreen extends StatefulWidget {
  const OtpCodeVerificationScreen({Key? key}) : super(key: key);

  @override
  _OtpCodeVerificationScreenState createState() =>
      _OtpCodeVerificationScreenState();
}

class _OtpCodeVerificationScreenState extends State<OtpCodeVerificationScreen>
    with SMSAutoFill {
  String? appSignature;
  String? otpCode;
  String? message;
  TextEditingController textEditingController = TextEditingController();

  // ..text = "123456";

  // ignore: close_sinks
  StreamController<ErrorAnimationType>? errorController;

  bool hasError = false;
  String currentText = "";
  final formKey = GlobalKey<FormState>();

  @override
  void codeUpdated(String code, String msg) {
    otpCode = code;
    message = msg;
    textEditingController.text = otpCode!;
    print("OTP Received : $otpCode");
    print("Message Received : $message");
    setState(() {});
    listenForCode();
  }

  @override
  void initState() {
    super.initState();
    listenForCode();
    errorController = StreamController<ErrorAnimationType>();
    SmsAutoDetect().getAppSignature.then((signature) {
      setState(() {
        appSignature = signature;
      });
    });
  }

  @override
  void dispose() {
    errorController!.close();
    super.dispose();
    cancel();
  }

  // snackBar Widget
  snackBar(String? message) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message!),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 18);
    return Scaffold(
      appBar: AppBar(
        title: Text("Otp Auto Detect"),
      ),
      body: Column(
        children: [
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Phone Number Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 8),
            child: RichText(
              text: TextSpan(
                text: "Enter the code sent to ",
                children: [
                  TextSpan(
                    text: "+123456789120",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Text(
              "This is the current app signature: $appSignature",
            ),
          ),
          const Spacer(),
          PinCodeTextField(
            autoDisposeControllers: false,
            appContext: context,
            pastedTextStyle: TextStyle(
              color: Colors.green.shade600,
              fontWeight: FontWeight.bold,
            ),
            length: 6,
            obscureText: false,
            obscuringCharacter: '*',
            // obscuringWidget: Icon(Icons.vpn_key_rounded),
            blinkWhenObscuring: true,
            animationType: AnimationType.fade,
            validator: (v) {
              // if (v!.length < 6) {
              //   return "I'm from validator";
              // } else {
              //   return null;
              // }
            },
            pinTheme: PinTheme(
              fieldOuterPadding: EdgeInsets.only(left: 8, right: 8),
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(5),
              fieldHeight: 50,
              fieldWidth: 40,
              activeFillColor: Colors.white,
              inactiveFillColor: Colors.white,
              selectedColor: Colors.black54,
              selectedFillColor: Colors.white,
              inactiveColor: Colors.black54,
              activeColor: Colors.black54,
            ),
            cursorColor: Colors.black,
            animationDuration: Duration(milliseconds: 300),
            enableActiveFill: true,
            // autoDismissKeyboard: false,
            errorAnimationController: errorController,
            controller: textEditingController,
            keyboardType: TextInputType.number,
            mainAxisAlignment: MainAxisAlignment.center,
            boxShadows: [
              BoxShadow(
                offset: Offset(0, 1),
                color: Colors.black12,
                blurRadius: 10,
              )
            ],
            onCompleted: (v) {
              print("Completed");
            },
            onTap: () {
              print("Pressed");
            },
            onChanged: (value) {
              print(value);
              setState(() {
                currentText = value;
              });
            },
            beforeTextPaste: (text) {
              print("Allowing to paste $text");
              //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
              //but you can show anything you want here, like your pop up saying wrong paste format or etc
              return true;
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Builder(
              builder: (_) {
                if (otpCode == null) {
                  return Text("Listening for code...", style: textStyle);
                }
                return Column(
                  children: [
                    Text("Code Received: $otpCode", style: textStyle),
                    Text("Message Received: $message", style: textStyle),
                  ],
                );
              },
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
