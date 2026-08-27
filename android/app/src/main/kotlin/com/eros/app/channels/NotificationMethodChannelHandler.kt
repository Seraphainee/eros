package com.eros.app.channels

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `NotificationMethodChannelHandler` — handler do MethodChannel
 * `eros.app/notification_channel`.
 *
 * Métodos:
 *  - `requestPermission` — abre settings (Android 13+) ou retorna true.
 *  - `areNotificationsEnabled` — checa status atual.
 *  - `openNotificationSettings` — abre settings do app.
 *  - `cancelAll` — limpa todas as notificações.
 */
class NotificationMethodChannelHandler(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eros.app/notification_channel"
    }

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> result.success(areNotificationsEnabled())
            "areNotificationsEnabled" -> result.success(areNotificationsEnabled())
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }
            "cancelAll" -> {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancelAll()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.areNotificationsEnabled()
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
