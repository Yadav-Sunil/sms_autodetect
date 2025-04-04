package com.sunil.sms_autodetect;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.telephony.TelephonyManager;
import android.util.Log;

import androidx.activity.result.IntentSenderRequest;
import androidx.annotation.NonNull;

import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest;
import com.google.android.gms.auth.api.identity.Identity;
import com.google.android.gms.auth.api.phone.SmsRetriever;
import com.google.android.gms.auth.api.phone.SmsRetrieverClient;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;

import java.lang.ref.WeakReference;
import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * SmsAutodetectPlugin
 */
public class SmsAutodetectPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler {
    private static final int PHONE_HINT_REQUEST = 11012;
    private static final String channelName = "sms_autodetect";

    private Activity activity;
    private Result pendingHintResult;
    private MethodChannel channel;
    private SmsBroadcastReceiver broadcastReceiver;
    private final PluginRegistry.ActivityResultListener activityResultListener = new PluginRegistry.ActivityResultListener() {

        @Override
        public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
            try {
                if (requestCode == PHONE_HINT_REQUEST && pendingHintResult != null) {
                    if (resultCode == Activity.RESULT_OK && data != null) {
                        String phoneNumber =
                                Identity.getSignInClient(activity).getPhoneNumberFromIntent(data);
                        pendingHintResult.success(phoneNumber);
                    } else {
                        pendingHintResult.success(null);
                    }
                    return true;
                }
            } catch (Exception e) {
                Log.e("Exception", e.toString());
            }
            return false;
        }
    };


    public SmsAutodetectPlugin() {
    }

    public void setCode(HashMap<String, String> map) {
        channel.invokeMethod("smscode", map);
    }

    @Override
    public void onMethodCall(MethodCall call, @NonNull final Result result) {
        switch (call.method) {
            case "requestPhoneHint":
                pendingHintResult = result;
                requestHint();
                break;
            case "listenForCode":
                final String smsCodeRegexPattern = call.argument("smsCodeRegexPattern");
                SmsRetrieverClient client = SmsRetriever.getClient(activity);
                Task<Void> task = client.startSmsRetriever();

                task.addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        unregisterReceiver();// unregister existing receiver
                        broadcastReceiver = new SmsBroadcastReceiver(new WeakReference<>(SmsAutodetectPlugin.this),
                                smsCodeRegexPattern);
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            activity.registerReceiver(broadcastReceiver,
                                    new IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION), Context.RECEIVER_EXPORTED);
                        } else {
                            activity.registerReceiver(broadcastReceiver,
                                    new IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION));
                        }
                        result.success(null);
                    }
                });

                task.addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        result.error("ERROR_START_SMS_RETRIEVER", "Can't start sms retriever", e);
                    }
                });
                break;
            case "unregisterListener":
                unregisterReceiver();
                result.success("successfully unregister receiver");
                break;
            case "getAppSignature":
                AppSignatureHelper signatureHelper = new AppSignatureHelper(activity.getApplicationContext());
                String appSignature = signatureHelper.getAppSignature();
                result.success(appSignature);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void requestHint() {

        if (!isSimSupport()) {
            if (pendingHintResult != null) {
                pendingHintResult.success(null);
            }
            return;
        }

        GetPhoneNumberHintIntentRequest request =
                GetPhoneNumberHintIntentRequest.builder().build();

        Identity.getSignInClient(activity)
                .getPhoneNumberHintIntent(request)
                .addOnSuccessListener(new OnSuccessListener<PendingIntent>() {
                    @Override
                    public void onSuccess(PendingIntent pendingIntent) {
                        try {
                            IntentSenderRequest intentSenderRequest = new IntentSenderRequest.Builder(pendingIntent).build();
                            activity.startIntentSenderForResult(
                                    intentSenderRequest.getIntentSender(),
                                    PHONE_HINT_REQUEST, null, 0, 0, 0
                            );
                        } catch (Exception e) {
                            e.printStackTrace();
                            pendingHintResult.error("ERROR", e.getMessage(), e);
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(Exception e) {
                        e.printStackTrace();
                        pendingHintResult.error("ERROR", e.getMessage(), e);
                    }
                });
    }

    public boolean isSimSupport() {
        TelephonyManager telephonyManager = (TelephonyManager) activity.getSystemService(Context.TELEPHONY_SERVICE);
        return !(telephonyManager.getSimState() == TelephonyManager.SIM_STATE_ABSENT);
    }

    private void setupChannel(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, channelName);
        channel.setMethodCallHandler(this);
    }

    private void unregisterReceiver() {
        if (broadcastReceiver != null) {
            try {
                activity.unregisterReceiver(broadcastReceiver);
            } catch (Exception ex) {
                // silent catch to avoir crash if receiver is not registered
            }
            broadcastReceiver = null;
        }
    }

    public void unregister() {
        unregisterReceiver();
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        setupChannel(binding.getBinaryMessenger());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        unregisterReceiver();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(activityResultListener);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        unregisterReceiver();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(activityResultListener);
    }

    @Override
    public void onDetachedFromActivity() {
        unregisterReceiver();
    }

}
