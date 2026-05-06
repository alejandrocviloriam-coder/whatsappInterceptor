package com.example.whatsapp_interceptor

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.regex.Pattern

/**
 * Servicio mejorado para escuchar notificaciones y detectar mensajes de WhatsApp entrantes
 * con mejor manejo de remitentes y destinatarios
 */
class WhatsAppNotificationService : NotificationListenerService() {
    private val TAG = "WhatsAppNotificationService"
    
    companion object {
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            Log.d("WhatsAppNotificationService", "setMethodChannel llamado - configurando canal")
        }
        
        // Verificar si el servicio de acceso a notificaciones está habilitado
        fun isNotificationAccessEnabled(context: Context): Boolean {
            val enabledNotificationListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            
            val expectedServiceName = context.packageName + "/" + WhatsAppNotificationService::class.java.canonicalName
            
            val isEnabled = enabledNotificationListeners?.contains(expectedServiceName) ?: false
            
            val status = if (isEnabled) "habilitado" else "NO habilitado"
            Log.d("WhatsAppNotificationService", "Servicio de notificaciones $status: $expectedServiceName")
            
            return isEnabled
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Servicio de notificaciones creado")
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener de notificaciones conectado")
        
        // Notificar a Flutter que el servicio está conectado
        // IMPORTANTE: Usar el mismo nombre que está esperando Flutter
        methodChannel?.invokeMethod("onNotificationServiceConnected", true)
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            // Solo procesar notificaciones de WhatsApp
            if (sbn.packageName != "com.whatsapp") {
                return
            }
            
            val extras = sbn.notification.extras ?: return
            
            // Extraer información del mensaje
            val title = extras.getString(Notification.EXTRA_TITLE) ?: return
            val text = extras.getString(Notification.EXTRA_TEXT) ?: return
            
            // Filtrar notificaciones de resumen que no queremos procesar
            if (shouldIgnoreNotification(title, text)) {
                Log.d(TAG, "Ignorando notificación de resumen: $title - $text")
                return
            }
            
            // Procesar la notificación según su tipo (grupo o individual)
            val messageData = processNotification(title, text)
            
            // Añadir datos comunes
            messageData["timestamp"] = System.currentTimeMillis().toString()
            messageData["direction"] = "incoming"
            messageData["isRead"] = false
            
            // Enviar mensaje a Flutter
            Log.d(TAG, "Mensaje entrante: ${messageData["content"]} (De: ${messageData["senderName"]})")
            methodChannel?.invokeMethod("onMessageIntercepted", messageData)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error al procesar notificación: ${e.message}")
        }
    }
    
    // Determina si una notificación debe ser ignorada
    private fun shouldIgnoreNotification(title: String, text: String): Boolean {
        // Ignorar notificaciones de la app de WhatsApp
        if (title == "WhatsApp") return true
        
        // Ignorar notificaciones de resumen (múltiples mensajes)
        if (title.contains("mensajes de") || title.contains("messages from")) return true
        
        // Ignorar notificaciones de resumen numéricas
        val summaryPatterns = listOf(
            "\\d+ mensajes? nuevos?".toRegex(RegexOption.IGNORE_CASE),
            "\\d+ new messages?".toRegex(RegexOption.IGNORE_CASE),
            "\\d+ chats? con \\d+ mensajes?".toRegex(RegexOption.IGNORE_CASE),
            "\\d+ chats? with \\d+ messages?".toRegex(RegexOption.IGNORE_CASE)
        )
        
        for (pattern in summaryPatterns) {
            if (pattern.containsMatchIn(text)) return true
        }
        
        return false
    }
    
    // Procesa una notificación y devuelve un mapa con los datos del mensaje
    private fun processNotification(title: String, text: String): HashMap<String, Any> {
        val messageData = HashMap<String, Any>()
        
        // Determinar si es un mensaje de grupo
        val isGroup = text.contains(":") && !text.startsWith(":")
        
        if (isGroup) {
            // Procesar mensaje de grupo
            val regex = Pattern.compile("^([^:]+): (.+)$")
            val matcher = regex.matcher(text)
            
            if (matcher.find()) {
                val sender = matcher.group(1)
                val content = matcher.group(2)
                
                messageData["content"] = content
                messageData["senderName"] = sender           // Remitente = miembro del grupo
                messageData["recipientName"] = title         // Destinatario = nombre del grupo
                messageData["recipientType"] = "group"
            } else {
                // Si no podemos extraer el formato, usar valores por defecto
                messageData["content"] = text
                messageData["senderName"] = "Miembro de grupo"
                messageData["recipientName"] = title
                messageData["recipientType"] = "group"
            }
        } else {
            // Procesar mensaje individual - CORREGIDO: asignar senderName
            messageData["content"] = text
            messageData["senderName"] = title        // Remitente = nombre del contacto (título de notificación)
            messageData["recipientName"] = "Tú"      // Destinatario = usuario (Tú)
            messageData["recipientType"] = "contact"
        }
        
        return messageData
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // No implementado pero podría usarse para detectar cuando se leen los mensajes
    }
}