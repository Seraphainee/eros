package com.eros.app.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.eros.app.MainActivity
import com.eros.app.R

/**
 * `VoiceForegroundService` — serviço em segundo plano que mantém
 * a sala de voz viva quando o app vai para background.
 *
 * **Importante:** Este serviço apenas MANTÉM a sessão ativa e exibe
 * a notificação persistente. O áudio em si é gerenciado pelo
 * `livekit_client` (Flutter) através de uma sessão de áudio
 * do Android, que continua rodando porque o app mantém um
 * processo vivo e o `livekit_client` faz `requestAudioFocus`.
 *
 * Ações da notificação:
 *  - Toque na notificação: abre [MainActivity] (Flutter).
 *  - "Mutar" / "Desmutar": envia intent [ACTION_TOGGLE_MUTE].
 *  - "Sair": envia intent [ACTION_STOP].
 *
 * Note: as ações são propagadas via broadcast/intent; o Flutter
 * observa via EventChannel. Em versões futuras, podemos enviar
 * direto para o Flutter via [VoiceMethodChannelHandler.onRoomUpdated].
 */
class VoiceForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "voice_room_channel"
        const val NOTIFICATION_ID = 42

        const val ACTION_START = "com.eros.app.voice.START"
        const val ACTION_STOP = "com.eros.app.voice.STOP"
        const val ACTION_UPDATE_MUTE = "com.eros.app.voice.UPDATE_MUTE"
        const val ACTION_TOGGLE_MUTE = "com.eros.app.voice.TOGGLE_MUTE"

        const val EXTRA_ROOM_ID = "roomId"
        const val EXTRA_ROOM_NAME = "roomName"
        const val EXTRA_IS_MUTED = "isMuted"

        @Volatile
        private var isMuted: Boolean = false

        @Volatile
        private var currentRoomName: String = "Sala de voz"

        @Volatile
        private var currentRoomId: String = ""

        fun isCurrentlyMuted() = isMuted
    }

    private lateinit var notificationManager: NotificationManager

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                currentRoomId = intent.getStringExtra(EXTRA_ROOM_ID) ?: currentRoomId
                currentRoomName = intent.getStringExtra(EXTRA_ROOM_NAME) ?: currentRoomName
                isMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, false)
                startForegroundCompat()
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_UPDATE_MUTE -> {
                isMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, isMuted)
                refreshNotification()
            }
            ACTION_TOGGLE_MUTE -> {
                isMuted = !isMuted
                refreshNotification()
                // Sinaliza ao Flutter via evento
                emitMuteState()
            }
        }
        return START_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sala de voz",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Mantém sua chamada de voz ativa em segundo plano"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun refreshNotification() {
        notificationManager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPending = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Ação toggle mute
        val toggleMuteIntent = Intent(this, VoiceForegroundService::class.java).apply {
            action = ACTION_TOGGLE_MUTE
        }
        val toggleMutePending = PendingIntent.getService(
            this,
            1,
            toggleMuteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Ação stop
        val stopIntent = Intent(this, VoiceForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val muteLabel = if (isMuted) "Desmutar" else "Mutar"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentRoomName)
            .setContentText(if (isMuted) "Microfone mutado" else "Conectado")
            .setSmallIcon(R.drawable.ic_voice)
            .setContentIntent(openAppPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .addAction(
                if (isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic,
                muteLabel,
                toggleMutePending,
            )
            .addAction(R.drawable.ic_call_end, "Sair", stopPending)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun emitMuteState() {
        // EventChannel é enviado pelo Flutter; aqui apenas logamos
        // para debug. A propagação real será feita via
        // VoiceMethodChannelHandler.onRoomUpdated em versão futura.
        android.util.Log.d("VoiceService", "mute changed: isMuted=$isMuted")
    }
}
