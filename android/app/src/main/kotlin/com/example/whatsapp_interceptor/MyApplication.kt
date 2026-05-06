package com.example.whatsapp_interceptor

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {
    companion object {
        const val ENGINE_ID = "accessibility_engine"
        const val TAG = "WhatsAppInterceptor"
    }
    
    override fun onCreate() {
        super.onCreate()
        
        Log.d(TAG, "Aplicación inicializada")
        
        // Crear y precachear un FlutterEngine para comunicación con el servicio de accesibilidad
        val flutterEngine = FlutterEngine(this)
        
        // Inicializar el motor Dart
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        // Guardar el motor en caché para que el servicio de accesibilidad pueda usarlo
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        
        Log.d(TAG, "Motor Flutter precacheado para el servicio de accesibilidad")
    }
}