package com.eros.app

import android.os.Bundle
import com.eros.app.channels.NotificationMethodChannelHandler
import com.eros.app.channels.VoiceMethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private var voiceHandler: VoiceMethodChannelHandler? = null
    private var notificationHandler: NotificationMethodChannelHandler? = null
    private var voiceEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Canal de comando de voz
        voiceHandler = VoiceMethodChannelHandler(applicationContext).also { handler ->
            handler.attach(messenger)
            handler.onRoomUpdated = { payload ->
                voiceEventSink?.success(payload)
            }
        }

        // Canal de notificação
        notificationHandler = NotificationMethodChannelHandler(applicationContext).also { handler ->
            handler.attach(messenger)
        }

        // EventChannel para eventos da sala -> Flutter
        EventChannel(messenger, "eros.app/voice_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    voiceEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    voiceEventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        voiceHandler?.detach()
        notificationHandler?.detach()
        voiceEventSink = null
        super.onDestroy()
    }
}
