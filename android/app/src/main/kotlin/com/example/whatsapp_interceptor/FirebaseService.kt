package com.example.whatsapp_interceptor

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class FirebaseService private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "FirebaseService"
        private var instance: FirebaseService? = null
        
        // Cache para control de duplicados
        private val processedMessageIds = ConcurrentHashMap<String, Long>()
        
        fun getInstance(context: Context): FirebaseService {
            if (instance == null) {
                instance = FirebaseService(context.applicationContext)
            }
            return instance!!
        }
        
        // Verificar si un mensaje ya ha sido procesado
        fun isMessageProcessed(messageId: String): Boolean {
            return processedMessageIds.containsKey(messageId)
        }
        
        // Marcar un mensaje como procesado
        fun markMessageAsProcessed(messageId: String) {
            processedMessageIds[messageId] = System.currentTimeMillis()
        }
        
        // Limpiar mensajes antiguos
        fun cleanOldMessages() {
            val now = System.currentTimeMillis()
            val iterator = processedMessageIds.entries.iterator()
            
            while (iterator.hasNext()) {
                val entry = iterator.next()
                val timestamp = entry.value
                
                // Eliminar mensajes más antiguos que 24 horas
                if (now - timestamp > 24 * 60 * 60 * 1000) {
                    iterator.remove()
                }
            }
        }
    }
    
    private var firestore: FirebaseFirestore? = null
    private var isInitialized = false
    
    fun initFirebase() {
        if (isInitialized) return
        
        try {
            if (FirebaseApp.getApps(context).isEmpty()) {
                Log.w(TAG, "Firebase no está inicializado. Inicializando...")
                FirebaseApp.initializeApp(context)
            }
            
            firestore = FirebaseFirestore.getInstance()
            isInitialized = true
            Log.d(TAG, "Firebase inicializado correctamente")
        } catch (e: Exception) {
            Log.e(TAG, "Error al inicializar Firebase: ${e.message}")
        }
    }
    
    suspend fun sendMessageToFirestore(messageData: Map<String, Any>): Boolean {
        if (!isInitialized) {
            initFirebase()
        }
        
        if (firestore == null) {
            Log.e(TAG, "Firestore no está inicializado")
            return false
        }
        
        try {
            // Generar ID único para el mensaje
            val messageId = UUID.randomUUID().toString()
            
            // Crear mapa con los datos
            val finalData = HashMap<String, Any>(messageData)
            finalData["id"] = messageId
            
            // Guardar en Firestore
            firestore!!.collection("messages")
                .document(messageId)
                .set(finalData)
                .await()
            
            Log.d(TAG, "Mensaje guardado en Firestore con ID: $messageId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error al guardar mensaje en Firestore: ${e.message}")
            return false
        }
    }
    
    suspend fun updateContactInFirestore(name: String, type: String, deviceId: String): Boolean {
        if (!isInitialized) {
            initFirebase()
        }
        
        if (firestore == null) {
            Log.e(TAG, "Firestore no está inicializado")
            return false
        }
        
        try {
            // Formatear ID del contacto
            val contactId = name.replace(Regex("[.#$\\[\\]/]"), "_")
            
            // Datos del contacto
            val contactData = hashMapOf(
                "name" to name,
                "type" to type,
                "lastUpdated" to System.currentTimeMillis(),
                "deviceId" to deviceId
            )
            
            // Guardar en Firestore
            firestore!!.collection("contacts")
                .document(contactId)
                .set(contactData)
                .await()
            
            Log.d(TAG, "Contacto actualizado en Firestore: $contactId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error al actualizar contacto en Firestore: ${e.message}")
            return false
        }
    }
}