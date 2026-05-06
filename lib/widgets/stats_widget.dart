// lib/widgets/stats_widget.dart
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

class StatsWidget extends StatefulWidget {
  const StatsWidget({Key? key}) : super(key: key);

  @override
  State<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget> {
  static const String _tag = "StatsWidget";
  late Stream<List<WhatsAppMessage>> _messagesStream;
  
  // Colores de WhatsApp
  final Color _whatsappGreen = const Color(0xFF128C7E);
  final Color _whatsappLightGreen = const Color(0xFF25D366);
  
  @override
  void initState() {
    super.initState();
    _messagesStream = firebaseMessageService.messagesStream;
    
    // Debug para ver si se inicia correctamente
    logger.d(_tag, "StatsWidget inicializado");
  }
  
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Nunca';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate.isAtSameMomentAs(today)) {
      return 'Hoy a las ${DateFormat.Hm().format(dateTime)}';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      return 'Ayer a las ${DateFormat.Hm().format(dateTime)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  // Función mejorada para contar contactos únicos
  int _getUniqueContactsCount(List<WhatsAppMessage> messages) {
    // Mapa para normalizar contactos (clave: versión en minúsculas, valor: versión oficial)
    final Map<String, String> normalizedContacts = {};
    
    // Primero, procesar los mensajes salientes para establecer los nombres oficiales
    for (final message in messages) {
      if (message.direction == MessageDirection.outgoing) {
        final contactName = message.recipientName;
        if (contactName.isNotEmpty) {
          // Guardar la versión normalizada (usar minúsculas como clave para comparación)
          normalizedContacts[contactName.toLowerCase()] = contactName;
        }
      }
    }
    
    // Luego, procesar los mensajes entrantes
    for (final message in messages) {
      if (message.direction == MessageDirection.incoming) {
        final sender = message.senderName ?? message.recipientName;
        if (sender.isNotEmpty) {
          final lowerSender = sender.toLowerCase();
          
          // Si ya existe un nombre normalizado para este contacto, no lo sobrescribas
          if (!normalizedContacts.containsKey(lowerSender)) {
            normalizedContacts[lowerSender] = sender;
          }
        }
      }
    }
    
    return normalizedContacts.length;
  }

  @override
  Widget build(BuildContext context) {
    // Debug para verificar cuando se construye
    logger.d(_tag, "Construyendo StatsWidget");
    
    return StreamBuilder<List<WhatsAppMessage>>(
      stream: _messagesStream,
      initialData: firebaseMessageService.getMessages(),
      builder: (context, snapshot) {
        logger.d(_tag, "StreamBuilder data: ${snapshot.data?.length ?? 'null'} mensajes");
        
        final messages = snapshot.data ?? [];
        final todayMessages = firebaseMessageService.countMessagesToday();
        // Usar nuestra función mejorada en lugar de firebaseMessageService.getUniqueContacts().length
        final uniqueContacts = _getUniqueContactsCount(messages);
        final latestMessageTime = firebaseMessageService.getLatestMessageTimestamp();
        
        logger.d(_tag, "Estadísticas: $todayMessages mensajes hoy, $uniqueContacts contactos");
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart, color: _whatsappLightGreen, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Estadísticas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StatCard(
                  icon: Icons.message,
                  title: 'Mensajes interceptados hoy',
                  value: '$todayMessages',
                  color: _whatsappGreen,
                ),
                const SizedBox(height: 12),
                StatCard(
                  icon: Icons.people,
                  title: 'Contactos únicos',
                  value: '$uniqueContacts',
                  color: _whatsappGreen,
                ),
                const SizedBox(height: 12),
                StatCard(
                  icon: Icons.access_time,
                  title: 'Último mensaje interceptado',
                  value: _formatDateTime(latestMessageTime),
                  color: _whatsappGreen,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  
  const StatCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}