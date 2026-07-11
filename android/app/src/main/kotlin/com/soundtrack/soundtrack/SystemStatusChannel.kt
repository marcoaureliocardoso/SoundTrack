package com.soundtrack.soundtrack

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.BatteryManager
import android.view.WindowManager
import androidx.annotation.VisibleForTesting
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private val BLUETOOTH_DEVICE_TYPES =
    setOf(
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_BLE_SPEAKER,
        AudioDeviceInfo.TYPE_BLE_BROADCAST,
        AudioDeviceInfo.TYPE_HEARING_AID,
    )
private val WIRED_DEVICE_TYPES =
    setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_LINE_ANALOG,
        AudioDeviceInfo.TYPE_LINE_DIGITAL,
        AudioDeviceInfo.TYPE_AUX_LINE,
    )
private val USB_DEVICE_TYPES =
    setOf(
        AudioDeviceInfo.TYPE_USB_ACCESSORY,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_HEADSET,
    )
private val SPEAKER_DEVICE_TYPES =
    setOf(
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
    )

data class BatteryChannelStatus(
    val percent: Int?,
    val charging: Boolean,
) {
    fun toChannelMap(): Map<String, Any?> =
        mapOf(
            "percent" to percent,
            "charging" to charging,
        )
}

@VisibleForTesting
internal fun mapBatteryStatus(
    level: Int,
    scale: Int,
    status: Int,
): BatteryChannelStatus {
    val percent =
        if (level >= 0 && scale > 0) {
            ((level.toLong() * 100) / scale).coerceIn(0, 100).toInt()
        } else {
            null
        }
    val charging =
        status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
    return BatteryChannelStatus(percent = percent, charging = charging)
}

@VisibleForTesting
internal fun mapOutputRouteLabel(deviceTypes: Collection<Int>): String {
    return when {
        deviceTypes.any { it in BLUETOOTH_DEVICE_TYPES } -> "Bluetooth"
        deviceTypes.any { it in WIRED_DEVICE_TYPES } -> "Fone com fio"
        deviceTypes.any { it in USB_DEVICE_TYPES } -> "USB"
        deviceTypes.any { it in SPEAKER_DEVICE_TYPES } -> "Alto-falante"
        else -> "Saída de áudio"
    }
}

/**
 * Returns null when notification-policy access is unavailable. With access,
 * only Android's explicit enabled and disabled filters produce a boolean.
 */
@VisibleForTesting
internal fun mapDoNotDisturb(
    policyAccessGranted: Boolean,
    interruptionFilter: Int,
): Boolean? {
    if (!policyAccessGranted) return null
    return when (interruptionFilter) {
        NotificationManager.INTERRUPTION_FILTER_ALL -> false
        NotificationManager.INTERRUPTION_FILTER_PRIORITY,
        NotificationManager.INTERRUPTION_FILTER_ALARMS,
        NotificationManager.INTERRUPTION_FILTER_NONE,
        -> true
        else -> null
    }
}

@VisibleForTesting
internal fun readDoNotDisturb(
    policyAccessGranted: Boolean,
    interruptionFilter: () -> Int,
): Boolean? {
    if (!policyAccessGranted) return null
    return mapDoNotDisturb(
        policyAccessGranted = true,
        interruptionFilter = interruptionFilter(),
    )
}

class SystemStatusChannel(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val audioManager =
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notificationManager =
        activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (disposed) {
            result.error("channel_disposed", "System status channel is disposed", null)
            return
        }
        when (call.method) {
            "mediaVolume" -> result.success(readMediaVolume())
            "battery" -> result.success(readBattery().toChannelMap())
            "outputRoute" -> result.success(readOutputRoute())
            "doNotDisturb" -> result.success(readDoNotDisturb())
            "setKeepScreenOn" -> setKeepScreenOn(call, result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
    }

    private fun readMediaVolume(): Map<String, Int> {
        return mapOf(
            "current" to audioManager.getStreamVolume(AudioManager.STREAM_MUSIC),
            "max" to audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
        )
    }

    @Suppress("DEPRECATION")
    private fun readBattery(): BatteryChannelStatus {
        val intent =
            activity.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            )
        if (intent == null) {
            return BatteryChannelStatus(percent = null, charging = false)
        }
        return mapBatteryStatus(
            level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1),
            scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1),
            status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN),
        )
    }

    private fun readOutputRoute(): String {
        val types =
            audioManager
                .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .map(AudioDeviceInfo::getType)
        return mapOutputRouteLabel(types)
    }

    private fun readDoNotDisturb(): Boolean? {
        return readDoNotDisturb(
            policyAccessGranted = notificationManager.isNotificationPolicyAccessGranted,
        ) { notificationManager.currentInterruptionFilter }
    }

    private fun setKeepScreenOn(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) {
            result.error("bad_args", "enabled must be a boolean", null)
            return
        }
        activity.runOnUiThread {
            if (disposed) {
                result.error("channel_disposed", "System status channel is disposed", null)
                return@runOnUiThread
            }
            if (enabled) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            result.success(null)
        }
    }

    private companion object {
        const val CHANNEL_NAME = "com.soundtrack/system_status"
    }
}
