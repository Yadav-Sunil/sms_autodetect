#import <Flutter/Flutter.h>
#import "./include/sms_autodetect/SmsAutodetectPlugin.h"

@interface SmsAutodetectPlugin () <FlutterPlugin>
@end

@implementation SmsAutodetectPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel =
      [FlutterMethodChannel methodChannelWithName:@"sms_autodetect"
                                  binaryMessenger:[registrar messenger]];
  SmsAutodetectPlugin* instance = [[SmsAutodetectPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"requestPhoneHint" isEqualToString:call.method]) {
    result(nil);
  } else if ([@"listenForCode" isEqualToString:call.method]) {
    result(nil);
  } else if ([@"unregisterListener" isEqualToString:call.method]) {
    result(nil);
  } else if ([@"getAppSignature" isEqualToString:call.method]) {
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}
@end
