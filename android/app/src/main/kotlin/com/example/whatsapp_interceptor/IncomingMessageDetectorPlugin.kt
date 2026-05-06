package com.example.whatsapp_interceptor

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger

class IncomingMessageDetectorPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private val TAG = "IncomingMessageDetector"
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.whatsapp_interceptor/incoming_message_detector")
        channel.setMethodCallHandler(this)
        
        // Conectar canal al servicio de notificaciones
        WhatsAppNotificationService.setMethodChannel(channel)
        
        Log.d(TAG, "Plugin detector de mensajes entrantes inicializado")
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        // Verificar si context está inicializado
        if (context == null) {
            result.error("NO_CONTEXT", "Context no inicializado", null)
            return
        }
        
        when (call.method) {
            "isServiceRunning" -> {
                // Comprobar si el servicio está habilitado en las notificaciones
                val isRunning = isNotificationServiceEnabled()
                Log.d(TAG, "Comprobando si el servicio está activo: $isRunning")
                result.success(isRunning)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun isNotificationServiceEnabled(): Boolean {
        // Implementa una verificación básica - puedes mejorarla después
        return try {
            // Intenta acceder al servicio - si no está disponible, devolverá false
            val manager = context?.getSystemService(Context.NOTIFICATION_SERVICE)
            manager != null
        } catch (e: Exception) {
            Log.e(TAG, "Error al verificar servicio de notificaciones: ${e.message}")
            false
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    companion object {
        fun registerWith(messenger: BinaryMessenger) {
            val channel = MethodChannel(messenger, "com.example.whatsapp_interceptor/incoming_message_detector")
            val plugin = IncomingMessageDetectorPlugin()
            // El contexto se inicializará más tarde durante onAttachedToEngine
            channel.setMethodCallHandler(plugin)
        }
    }
}