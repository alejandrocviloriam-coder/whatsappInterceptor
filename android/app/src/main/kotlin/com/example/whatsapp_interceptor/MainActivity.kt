package com.example.whatsapp_interceptor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.provider.Settings

class MainActivity: FlutterActivity() {
    private val ACTIVATION_CHANNEL = "com.example.whatsapp_interceptor/activation"
    private val ACCESSIBILITY_CHANNEL = "com.example.whatsapp_interceptor/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para activationCode
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveActivationCode") {
                val code = call.argument<String>("code")
                if (code != null) {
                    saveActivationCodeToPrefs(code)
                    result.success(true)
                } else {
                    result.error("NO_CODE", "No activation code provided", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Canal para accesibilidad
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "openAccessibilitySettings") {
                openAccessibilitySettings()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveActivationCodeToPrefs(code: String) {
        val prefs = getSharedPreferences("whatsapp_interceptor_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("activation_code", code).apply()
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}