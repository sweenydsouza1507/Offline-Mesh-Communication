package com.example.crowdlink

import android.app.*
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MeshForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "mesh_service"
        val channel = NotificationChannel(
            channelId, "Mesh Service",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("CrowdLink")
            .setContentText("Mesh network active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)
        return START_STICKY
    }
}