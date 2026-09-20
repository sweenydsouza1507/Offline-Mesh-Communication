package com.example.crowdlink

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        val serviceIntent = Intent(this, MeshForegroundService::class.java)
        startForegroundService(serviceIntent)
    }
}