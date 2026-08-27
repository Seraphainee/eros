package com.eros.app.channels

import android.content.Context
import android.content.Intent
import android.os.Build
import com.eros.app.voice.VoiceForegroundService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `VoiceMethodChannelHandler` — handler do MethodChannel `eros.app/voice_channel`.
 *
 * Comandos suportados:
 *  - `startVoiceService` (roomId, roomName, isMuted)
 *  - `stopVoiceService`
 *  - `updateMuteState` (isMuted)
 *
 * Emite eventos pelo [onRoomUpdated] (consumido pelo Flutter via
 * EventChannel `eros.app/voice_events`).
 */
class VoiceMethodChannelHandler(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eros.app/voice_channel"
    }

    private var channel: MethodChannel? = null

    /** Callback para o Flutter receber eventos do serviço. */
    var onRoomUpdated: ((Map<String, Any?>) -> Unit)? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVoiceService" -> {
                val roomId = call.argument<String>("roomId") ?: ""
                val roomName = call.argument<String>("roomName") ?: "Sala de voz"
                val isMuted = call.argument<Boolean>("isMuted") ?: false
                startVoiceService(roomId, roomName, isMuted)
                result.success(null)
            }
            "stopVoiceService" -> {
                stopVoiceService()
                result.success(null)
            }
            "updateMuteState" -> {
                val isMuted = call.argument<Boolean>("isMuted") ?: false
                updateMuteState(isMuted)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startVoiceService(roomId: String, roomName: String, isMuted: Boolean) {
        val intent = Intent(context, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_START
            putExtra(VoiceForegroundService.EXTRA_ROOM_ID, roomId)
            putExtra(VoiceForegroundService.EXTRA_ROOM_NAME, roomName)
            putExtra(VoiceForegroundService.EXTRA_IS_MUTED, isMuted)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopVoiceService() {
        val intent = Intent(context, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_STOP
        }
        context.startService(intent)
    }

    private fun updateMuteState(isMuted: Boolean) {
        val intent = Intent(context, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_UPDATE_MUTE
            putExtra(VoiceForegroundService.EXTRA_IS_MUTED, isMuted)
        }
        context.startService(intent)
    }
}
