package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Servicio en primer plano que mantiene vivo el proceso `cloudflared` (quick tunnel)
 * y reduce el riesgo de que el sistema lo mate al apagar la pantalla.
 */
class CloudflaredQuickTunnelService : Service() {
    companion object {
        const val CHANNEL_ID = "openclaw_cloudflared_tunnel"
        const val NOTIFICATION_ID = 5

        @Volatile
        var publicTunnelUrl: String? = null

        @Volatile
        var isServiceRunning: Boolean = false

        private var instance: CloudflaredQuickTunnelService? = null

        fun start(context: Context) {
            publicTunnelUrl = null
            val intent = Intent(context, CloudflaredQuickTunnelService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CloudflaredQuickTunnelService::class.java)
            context.stopService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var worker: Thread? = null
    private lateinit var processManager: ProcessManager

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isServiceRunning) {
            return START_STICKY
        }
        isServiceRunning = true
        instance = this
        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
        processManager = ProcessManager(filesDir, nativeLibDir)

        startForeground(NOTIFICATION_ID, buildNotification("Iniciando túnel Cloudflare…"))
        acquireWakeLock()

        worker = Thread {
            try {
                val url = processManager.startCloudflaredQuickTunnelAndAwaitUrl(120_000L)
                publicTunnelUrl = url
                instance?.updateNotification("Túnel activo (Cloudflare)\n$url")
            } catch (_: Exception) {
                publicTunnelUrl = null
                stopSelf()
            }
        }.apply {
            isDaemon = true
            name = "openclaw-cloudflared-worker"
            start()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isServiceRunning = false
        instance = null
        worker?.interrupt()
        worker = null
        try {
            if (::processManager.isInitialized) {
                processManager.stopCloudflaredQuickTunnel()
            }
        } catch (_: Exception) {
        }
        publicTunnelUrl = null
        releaseWakeLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClawES::CloudflaredTunnelWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OpenClaw ES — túnel remoto",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene cloudflared activo para acceso remoto"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("OpenClaw ES — acceso remoto")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {
        }
    }
}
