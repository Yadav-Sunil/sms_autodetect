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
    private static final String ERROR_NO_ACTIVITY = "ERROR_NO_ACTIVITY";

    private Activity activity;
    private Context applicationContext;
    private ActivityPluginBinding activityBinding;
    private Result pendingHintResult;
    private MethodChannel channel;
    private SmsBroadcastReceiver broadcastReceiver;
    private final PluginRegistry.ActivityResultListener activityResultListener = new PluginRegistry.ActivityResultListener() {

        @Override
        public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
            if (requestCode != PHONE_HINT_REQUEST || pendingHintResult == null) {
                return false;
            }

            Result result = pendingHintResult;
            pendingHintResult = null;

            try {
                if (resultCode == Activity.RESULT_OK && data != null && activity != null) {
                    String phoneNumber =
                            Identity.getSignInClient(activity).getPhoneNumberFromIntent(data);
                    result.success(phoneNumber);
                } else {
                    result.success(null);
                }
            } catch (Exception e) {
                Log.e("SmsAutodetectPlugin", "Phone hint result failed", e);
                result.error("ERROR_PHONE_HINT", e.getMessage(), e);
            }
            return true;
        }
    };


    public SmsAutodetectPlugin() {
    }

    public void setCode(HashMap<String, String> map) {
        if (channel != null) {
            channel.invokeMethod("smscode", map);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, @NonNull final Result result) {
        switch (call.method) {
            case "requestPhoneHint":
                finishPendingHintSuccess(null);
                pendingHintResult = result;
                requestHint();
                break;
            case "listenForCode":
                if (activity == null) {
                    result.error(ERROR_NO_ACTIVITY, "SmsAutodetectPlugin requires an attached Activity.", null);
                    break;
                }

                final String smsCodeRegexPattern = call.argument("smsCodeRegexPattern");
                SmsRetrieverClient client = SmsRetriever.getClient(activity);
                Task<Void> task = client.startSmsRetriever();

                task.addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        if (activity == null) {
                            result.error(ERROR_NO_ACTIVITY, "SmsAutodetectPlugin requires an attached Activity.", null);
                            return;
                        }
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
                Context context = applicationContext != null
                        ? applicationContext
                        : activity != null ? activity.getApplicationContext() : null;
                if (context == null) {
                    result.error(ERROR_NO_ACTIVITY, "SmsAutodetectPlugin requires an Android context.", null);
                    break;
                }
                AppSignatureHelper signatureHelper = new AppSignatureHelper(context);
                String appSignature = signatureHelper.getAppSignature();
                result.success(appSignature);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void requestHint() {
        final Activity currentActivity = activity;
        if (currentActivity == null) {
            finishPendingHintSuccess(null);
            return;
        }

        if (!isSimSupport(currentActivity)) {
            finishPendingHintSuccess(null);
            return;
        }

        GetPhoneNumberHintIntentRequest request =
                GetPhoneNumberHintIntentRequest.builder().build();

        Identity.getSignInClient(currentActivity)
                .getPhoneNumberHintIntent(request)
                .addOnSuccessListener(new OnSuccessListener<PendingIntent>() {
                    @Override
                    public void onSuccess(PendingIntent pendingIntent) {
                        if (activity == null) {
                            finishPendingHintSuccess(null);
                            return;
                        }
                        try {
                            IntentSenderRequest intentSenderRequest = new IntentSenderRequest.Builder(pendingIntent).build();
                            activity.startIntentSenderForResult(
                                    intentSenderRequest.getIntentSender(),
                                    PHONE_HINT_REQUEST, null, 0, 0, 0
                            );
                        } catch (Exception e) {
                            Log.e("SmsAutodetectPlugin", "Failed to request phone hint", e);
                            finishPendingHintError("ERROR_PHONE_HINT", e.getMessage(), e);
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(Exception e) {
                        Log.e("SmsAutodetectPlugin", "Failed to create phone hint intent", e);
                        finishPendingHintError("ERROR_PHONE_HINT", e.getMessage(), e);
                    }
                });
    }

    public boolean isSimSupport(Activity activity) {
        TelephonyManager telephonyManager = (TelephonyManager) activity.getSystemService(Context.TELEPHONY_SERVICE);
        return telephonyManager != null
                && telephonyManager.getSimState() != TelephonyManager.SIM_STATE_ABSENT;
    }

    private void setupChannel(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, channelName);
        channel.setMethodCallHandler(this);
    }

    private void unregisterReceiver() {
        if (broadcastReceiver != null) {
            try {
                if (activity != null) {
                    activity.unregisterReceiver(broadcastReceiver);
                }
            } catch (Exception ex) {
                Log.d("SmsAutodetectPlugin", "Receiver was already unregistered.", ex);
            }
            broadcastReceiver = null;
        }
    }

    private void finishPendingHintSuccess(String value) {
        Result result = pendingHintResult;
        pendingHintResult = null;
        if (result != null) {
            result.success(value);
        }
    }

    private void finishPendingHintError(String code, String message, Exception exception) {
        Result result = pendingHintResult;
        pendingHintResult = null;
        if (result != null) {
            result.error(code, message, exception);
        }
    }

    public void unregister() {
        unregisterReceiver();
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        setupChannel(binding.getBinaryMessenger());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        unregisterReceiver();
        finishPendingHintSuccess(null);
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        applicationContext = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        attachToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        attachToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachFromActivity();
    }

    private void attachToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();
        binding.addActivityResultListener(activityResultListener);
    }

    private void detachFromActivity() {
        unregisterReceiver();
        finishPendingHintSuccess(null);
        if (activityBinding != null) {
            activityBinding.removeActivityResultListener(activityResultListener);
            activityBinding = null;
        }
        activity = null;
    }

}
