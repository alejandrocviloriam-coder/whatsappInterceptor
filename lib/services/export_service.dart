// lib/services/export_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:whatsapp_interceptor/services/message_storage_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  
  ExportService._internal();
  
  // Método para exportar mensajes de un contacto específico
  Future<bool> exportMessages({
    required String contactName, 
    List<WhatsAppMessage>? messages,
  }) async {
    try {
      // Verificar permisos de almacenamiento
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return false;
      }
      
      // Obtener mensajes (si no se proporcionan)
      // Filtrar mensajes por contacto si no se proporcionan explícitamente
      final exportMessages = messages ?? 
          messageStorageService.getMessages().where(
            (msg) => msg.recipientName == contactName || msg.senderName == contactName
          ).toList();
      
      if (exportMessages.isEmpty) {
        return false;
      }
      
      // Crear archivo JSON
      final jsonData = jsonEncode({
        'contactName': contactName,
        'exportDate': DateTime.now().toIso8601String(),
        'messages': exportMessages.map((msg) => msg.toJson()).toList(),
      });
      
      // Guardar archivo en almacenamiento
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return false;
      }
      
      // Crear directorio si no existe
      final exportDir = Directory('${directory.path}/WhatsAppInterceptor');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      // Nombre de archivo con fecha y hora
      final now = DateTime.now();
      final timestamp = 
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      final fileName = 'whatsapp_${contactName.replaceAll(' ', '_')}_$timestamp.json';
      final file = File('${exportDir.path}/$fileName');
      
      // Escribir datos
      await file.writeAsString(jsonData);
      
      // Devolver ruta del archivo
      if (kDebugMode) {
        print('Archivo exportado: ${file.path}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al exportar mensajes: $e');
      }
      return false;
    }
  }
  
  // Método para exportar todos los mensajes
  Future<bool> exportAllMessages() async {
    try {
      // Verificar permisos de almacenamiento
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return false;
      }
      
      // Obtener todos los mensajes
      final allMessages = messageStorageService.getMessages();
      
      if (allMessages.isEmpty) {
        return false;
      }
      
      // Crear archivo JSON
      final jsonData = jsonEncode({
        'exportDate': DateTime.now().toIso8601String(),
        'messages': allMessages.map((msg) => msg.toJson()).toList(),
      });
      
      // Guardar archivo en almacenamiento
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return false;
      }
      
      // Crear directorio si no existe
      final exportDir = Directory('${directory.path}/WhatsAppInterceptor');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      // Nombre de archivo con fecha y hora
      final now = DateTime.now();
      final timestamp = 
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      final fileName = 'whatsapp_all_messages_$timestamp.json';
      final file = File('${exportDir.path}/$fileName');
      
      // Escribir datos
      await file.writeAsString(jsonData);
      
      // Devolver ruta del archivo
      if (kDebugMode) {
        print('Archivo exportado: ${file.path}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al exportar todos los mensajes: $e');
      }
      return false;
    }
  }

  // Mostrar información sobre la ubicación de exportación
  Future<String> getExportLocation() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return 'No se pudo determinar la ubicación';
      }
      
      return '${directory.path}/WhatsAppInterceptor';
    } catch (e) {
      return 'No se pudo determinar la ubicación';
    }
  }
}

final exportService = ExportService();