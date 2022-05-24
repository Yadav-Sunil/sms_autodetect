## Getting Started
Flutter plugin to provide OTP code autofill support.

For iOS, this package is not needed as the SMS autoDetect is provided by default, but not for Android, that's where this package is useful.

No permission to read SMS messages is asked to the user as there no need thanks to SMSRetriever API.

## Usage
You have two widgets at your disposable for autoDetect an SMS code.

Just before you sent your phone number to the backend, you need to let know the plugin that it need to listen for the SMS with the code.

To do that you need to do:
```dart
await SmsAutoDetect().listenForCode;
```
This will listen for the SMS with the code when received, OTP autofill the PinCodeTextField widget.
```dart
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
              )
```
If you are using obscuringCharacter then not use obscuringWidget and using obscuringWidget then obscureText set false
```dart
obscureText: false,
```
If you want to auto dismiss keyboard when otp filled completed
```dart
autoDismissKeyboard: true,
```

### Android SMS constraint
For the code to be receive, it need to follow some rules as describe here: https://developers.google.com/identity/sms-retriever/verify
- Be no longer than 140 bytes
- Contain a one-time code that the client sends back to your server to complete the verification flow
- End with an 11-character hash string that identifies your app

Example of SMS:
```
ExampleApp: Your code is 123456
AC+7eBC8WFi
``` 

### Custom CodeAutoDetect
If you want to create a custom widget that will autoDetect with the sms code, you can use the SMSAutoFill mixin that will offer you:

### PhoneFieldHint [Android only]
PhoneFieldHint is a widget that will allow you ask for system phone number and autofill the widget if a phone is choosen by the user.

- `listenForCode()` to listen for the SMS code from the native plugin when SMS is received, need to be called on your initState.
- `cancel()` to dispose the subscription of the SMS code from the native plugin, need to be called on your dispose.
- `codeUpdated()` called when the code is received, you can access the value with the field code.
- `unregisterListener()` to unregister the broadcast receiver, need to be called on your dispose.

### App Signature 
To get the app signature at runtime just call the getter `getAppSignature` on `SmsAutoDetect`. You can also find the sample code in example app.
```dart
  Future<String> get getAppSignature async {
    final String? appSignature = await _channel.invokeMethod('getAppSignature');
    return appSignature ?? '';
  }
```
