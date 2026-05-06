// lib/services/contact_normalizer.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:whatsapp_interceptor/models/message.dart';

/// Servicio para normalizar nombres de contactos en mensajes de WhatsApp
/// Garantiza que un mismo contacto tenga el mismo identificador independientemente
/// de si el mensaje es entrante o saliente.
class ContactNormalizer {
  static final ContactNormalizer _instance = ContactNormalizer._internal();
  factory ContactNormalizer() => _instance;
  
  ContactNormalizer._internal();
  
  // Mapa de identificadores de contacto (nombre o número de teléfono)
  // Clave: identificador original, Valor: identificador normalizado
  Map<String, String> _contactIdentifiers = {};
  
  // Set de pares de contactos relacionados para buscar coincidencias más rápidamente
  // Formato: "contacto1|contacto2"
  Set<String> _contactPairs = {};
  
  // Verifica si dos contactos están relacionados (mismo contacto, diferentes nombres)
  bool areContactsRelated(String contact1, String contact2) {
    // Comprobar si ya existe un par registrado
    final pair1 = "${contact1.toLowerCase()}|${contact2.toLowerCase()}";
    final pair2 = "${contact2.toLowerCase()}|${contact1.toLowerCase()}";
    
    if (_contactPairs.contains(pair1) || _contactPairs.contains(pair2)) {
      return true;
    }
    
    // Verificar si tienen el mismo identificador normalizado
    final normalized1 = getNormalizedIdentifier(contact1);
    final normalized2 = getNormalizedIdentifier(contact2);
    
    return normalized1 == normalized2;
  }
  
  // Relaciona dos contactos explícitamente
  void relateContacts(String contact1, String contact2) {
    // Usar el primer contacto como el identificador normalizado para ambos
    _updateIdentifier(contact1, contact1);
    _updateIdentifier(contact2, contact1);
    
    // Registrar el par
    _contactPairs.add("${contact1.toLowerCase()}|${contact2.toLowerCase()}");
    
    // Guardar cambios
    _saveContactIdentifiers();
    
    if (kDebugMode) {
      print('[ContactNormalizer] Contactos relacionados: $contact1 <-> $contact2');
    }
  }
  
  // Obtiene un identificador normalizado para un contacto
  String getNormalizedIdentifier(String contactName) {
    final lowerContact = contactName.toLowerCase();
    
    // Comprobar si ya existe un identificador normalizado
    if (_contactIdentifiers.containsKey(lowerContact)) {
      return _contactIdentifiers[lowerContact]!;
    }
    
    // Buscar identificadores similares
    for (final entry in _contactIdentifiers.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Verificar coincidencia parcial significativa
      if (_areContactNamesRelated(lowerContact, key)) {
        _updateIdentifier(contactName, value);
        return value;
      }
    }
    
    // Si no hay coincidencias, usar el nombre original como identificador
    _updateIdentifier(contactName, contactName);
    return contactName;
  }
  
  // Comprueba si dos nombres de contacto podrían ser el mismo
  bool _areContactNamesRelated(String name1, String name2) {
    if (name1 == name2) return true;
    
    // Verificar si uno contiene al otro como parte del nombre/número
    if (name1.contains(name2) || name2.contains(name1)) {
      return true;
    }
    
    // Extraer números de teléfono potenciales y compararlos
    final number1 = _extractPhoneNumber(name1);
    final number2 = _extractPhoneNumber(name2);
    
    if (number1.isNotEmpty && number2.isNotEmpty) {
      // Comparar últimos dígitos si son números de teléfono
      if (number1.length >= 5 && number2.length >= 5) {
        final digits1 = number1.substring(number1.length - 5);
        final digits2 = number2.substring(number2.length - 5);
        return digits1 == digits2;
      }
    }
    
    return false;
  }
  
  // Extrae números de teléfono de un texto
  String _extractPhoneNumber(String text) {
    // Eliminar todo excepto dígitos
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }
  
  // Actualiza el identificador de un contacto
  void _updateIdentifier(String contactName, String normalizedName) {
    final lowerContact = contactName.toLowerCase();
    _contactIdentifiers[lowerContact] = normalizedName;
  }
  
  // Procesa un mensaje para normalizar sus contactos
  WhatsAppMessage processMessage(WhatsAppMessage message) {
    if (message.direction == MessageDirection.incoming) {
      // Mensaje entrante: normalizar remitente
      final senderName = message.senderName ?? message.recipientName;
      final normalizedName = getNormalizedIdentifier(senderName);
      
      // Si el nombre cambió, crear una copia con el nombre normalizado
      if (normalizedName != senderName) {
        return message.copyWith(senderName: normalizedName);
      }
    } else {
      // Mensaje saliente: normalizar destinatario
      final recipientName = message.recipientName;
      final normalizedName = getNormalizedIdentifier(recipientName);
      
      // Si el nombre cambió, crear una copia con el nombre normalizado
      if (normalizedName != recipientName) {
        return message.copyWith(recipientName: normalizedName);
      }
    }
    
    // Si no necesita normalización, devolver el mensaje original
    return message;
  }
  
  // Detecta y relaciona contactos entre mensajes entrantes y salientes
  void analyzeMessages(List<WhatsAppMessage> messages) {
    // Mapas para relacionar nombres de contactos con algún identificador (nombre, número, etc.)
    final Map<String, Set<String>> contactRelations = {};
    
    // Procesar todos los mensajes para encontrar relaciones
    for (final message in messages) {
      if (message.direction == MessageDirection.outgoing) {
        // Para mensajes salientes, el contacto es el destinatario
        final contactName = message.recipientName;
        final normalizedName = getNormalizedIdentifier(contactName);
        
        if (!contactRelations.containsKey(normalizedName)) {
          contactRelations[normalizedName] = {};
        }
        contactRelations[normalizedName]!.add(contactName);
      } else {
        // Para mensajes entrantes, el contacto es el remitente
        final contactName = message.senderName ?? message.recipientName; // CAMBIO AQUÍ
        if (contactName != 'Desconocido') {
          final normalizedName = getNormalizedIdentifier(contactName);
          
          if (!contactRelations.containsKey(normalizedName)) {
            contactRelations[normalizedName] = {};
          }
          contactRelations[normalizedName]!.add(contactName);
        }
      }
    }
    
    // Buscar mensajes que podrían ser del mismo contacto pero con diferentes nombres
    for (final msg1 in messages) {
      for (final msg2 in messages) {
        // Solo comparar mensajes de distintas direcciones
        if (msg1.direction == msg2.direction) continue;
        
        String name1, name2;
        
        if (msg1.direction == MessageDirection.incoming) {
          name1 = msg1.senderName ?? msg1.recipientName; // CAMBIO AQUÍ
          name2 = msg2.recipientName;
        } else {
          name1 = msg1.recipientName;
          name2 = msg2.senderName ?? msg2.recipientName; // CAMBIO AQUÍ
        }
        
        // Ignorar 'Desconocido'
        if (name1 == 'Desconocido' || name2 == 'Desconocido') continue;
        
        // Si los nombres son similares pero no idénticos, relacionarlos
        if (!areContactsRelated(name1, name2) && _areContactNamesRelated(name1.toLowerCase(), name2.toLowerCase())) {
          if (kDebugMode) {
            print('[ContactNormalizer] Nombres potencialmente relacionados: $name1 <-> $name2');
          }
          
          // Preferir el nombre que no parece ser un número de teléfono
          if (_looksLikePhoneNumber(name1) && !_looksLikePhoneNumber(name2)) {
            relateContacts(name2, name1); // name2 es el identificador principal
          } else if (_looksLikePhoneNumber(name2) && !_looksLikePhoneNumber(name1)) {
            relateContacts(name1, name2); // name1 es el identificador principal
          } else {
            // Si ambos son números o ninguno lo es, preferir el más largo
            if (name1.length >= name2.length) {
              relateContacts(name1, name2);
            } else {
              relateContacts(name2, name1);
            }
          }
        }
      }
    }
  }
  
  // Determina si un texto parece ser un número de teléfono
  bool _looksLikePhoneNumber(String text) {
    final digitsCount = text.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digitsCount >= 6; // Si tiene al menos 6 dígitos, probablemente es un número
  }
  
  // Carga identificadores guardados
  Future<void> loadContactIdentifiers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar identificadores
      final identifiersJson = prefs.getString('contact_identifiers');
      if (identifiersJson != null) {
        final Map<String, dynamic> data = jsonDecode(identifiersJson);
        _contactIdentifiers = data.map((key, value) => MapEntry(key, value.toString()));
      }
      
      // Cargar pares de contactos
      final pairsJson = prefs.getString('contact_pairs');
      if (pairsJson != null) {
        final List<dynamic> pairs = jsonDecode(pairsJson);
        _contactPairs = pairs.map((item) => item.toString()).toSet();
      }
      
      if (kDebugMode) {
        print('[ContactNormalizer] Contactos cargados: ${_contactIdentifiers.length}, Pares: ${_contactPairs.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ContactNormalizer] Error al cargar contactos: $e');
      }
      // Si hay error, reiniciar mapas
      _contactIdentifiers = {};
      _contactPairs = {};
    }
  }
  
  // Guarda identificadores
  Future<void> _saveContactIdentifiers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar identificadores
      await prefs.setString('contact_identifiers', jsonEncode(_contactIdentifiers));
      
      // Guardar pares de contactos
      await prefs.setString('contact_pairs', jsonEncode(_contactPairs.toList()));
      
      if (kDebugMode) {
        print('[ContactNormalizer] Contactos guardados: ${_contactIdentifiers.length}, Pares: ${_contactPairs.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ContactNormalizer] Error al guardar contactos: $e');
      }
    }
  }
}

// Instancia global
final contactNormalizer = ContactNormalizer();