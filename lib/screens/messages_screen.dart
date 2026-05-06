// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const MessagesScreen({
    Key? key,
    required this.contactId,
    required this.contactName,
  }) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const String _tag = "MessagesScreen";
  bool _isLoading = true;
  
  // Colores de WhatsApp
  final Color _whatsappGreen = const Color(0xFF128C7E);
  final Color _whatsappLightGreen = const Color(0xFF25D366);
  final Color _whatsappDarkGreen = const Color(0xFF075E54);
  final Color _chatBackgroundColor = const Color(0xFF121B22);
  
  // Stream para escuchar mensajes en tiempo real
  late Stream<List<WhatsAppMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en mensajes en tiempo real
    _messagesStream = FirebaseMessageService().messagesStream;
    
    // Establecer que ya no estamos cargando después de iniciar
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    logger.d(_tag, "MessagesScreen inicializado para contacto: ${widget.contactName}");
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }
  
  // Método para convertir un objeto a DateTime
  DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp is DateTime) {
      return timestamp;
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else {
      return DateTime.now(); // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBackgroundColor,
      appBar: AppBar(
        backgroundColor: _whatsappDarkGreen,
        elevation: 0,
        leadingWidth: 30,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          iconSize: 22,
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _whatsappGreen.withAlpha(50),
              child: Text(
                widget.contactName.isNotEmpty 
                    ? widget.contactName[0].toUpperCase() 
                    : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'interceptado',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _showClearConfirmationDialog();
                  break;
                case 'info':
                  _showContactInfoDialog();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Info del contacto', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Borrar mensajes', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_whatsappGreen),
              ),
            )
          : StreamBuilder<List<WhatsAppMessage>>(
              stream: _messagesStream,
              initialData: FirebaseMessageService().getMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar mensajes: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 50,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay mensajes aún',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Filtrar mensajes solo para este contacto
                final allMessages = snapshot.data!;
                final contactMessages = allMessages.where((message) {
                  final recipientMatch = message.recipientName.toLowerCase() == widget.contactName.toLowerCase();
                  final senderMatch = message.senderName != null && 
                                     message.senderName!.toLowerCase() == widget.contactName.toLowerCase();
                  return recipientMatch || senderMatch;
                }).toList();
                
                // Si no hay mensajes para este contacto
                if (contactMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 50,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay mensajes para este contacto',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Convertir mensajes a formato para la interfaz
                final messages = contactMessages.map((m) => {
                  'content': m.content,
                  'isOutgoing': m.direction == MessageDirection.outgoing,
                  'timestamp': m.timestamp,
                  'senderName': m.senderName,
                  'recipientName': m.recipientName,
                }).toList();
                
                // Ordenar por timestamp (más recientes primero)
                messages.sort((a, b) {
                  final DateTime timeA = _parseDateTime(a['timestamp']);
                  final DateTime timeB = _parseDateTime(b['timestamp']);
                  return timeB.compareTo(timeA);
                });
                
                // Agrupar mensajes por fecha
                final Map<String, List<Map<String, dynamic>>> groupedMessages = {};
                
                for (var message in messages) {
                  final timestamp = _parseDateTime(message['timestamp']);
                  final dateKey = _getDateKey(timestamp);
                  
                  if (!groupedMessages.containsKey(dateKey)) {
                    groupedMessages[dateKey] = [];
                  }
                  
                  groupedMessages[dateKey]!.add(message);
                }
                
                // Obtener las fechas ordenadas (más recientes primero)
                final dates = groupedMessages.keys.toList();
                dates.sort((a, b) {
                  final DateTime dateA = _getDateFromKey(a);
                  final DateTime dateB = _getDateFromKey(b);
                  return dateB.compareTo(dateA);
                });
                
                // Construir la lista de mensajes agrupados por fecha
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dates.length,
                  reverse: true,
                  itemBuilder: (context, dateIndex) {
                    final date = dates[dateIndex];
                    final messagesForDate = groupedMessages[date]!;
                    
                    // Ordenar mensajes dentro del grupo (antiguos primero)
                    messagesForDate.sort((a, b) {
                      final DateTime timeA = _parseDateTime(a['timestamp']);
                      final DateTime timeB = _parseDateTime(b['timestamp']);
                      return timeA.compareTo(timeB);
                    });
                    
                    return Column(
                      children: [
                        // Encabezado de fecha para este grupo
                        _buildDateHeaderFromKey(date),
                        
                        // Lista de mensajes para esta fecha
                        ...messagesForDate.map((message) {
                          final isOutgoing = message['isOutgoing'] == true;
                          final content = message['content']?.toString() ?? '';
                          final timestamp = _parseDateTime(message['timestamp']);
                          
                          return Align(
                            alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.fromLTRB(
                                isOutgoing ? 12 : 16, 
                                8, 
                                isOutgoing ? 16 : 12, 
                                8
                              ),
                              decoration: BoxDecoration(
                                color: isOutgoing ? _whatsappLightGreen : Colors.grey[800],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isOutgoing ? 8 : 0),
                                  topRight: Radius.circular(isOutgoing ? 0 : 8),
                                  bottomLeft: const Radius.circular(8),
                                  bottomRight: const Radius.circular(8),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: isOutgoing ? Colors.black : Colors.white,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            color: isOutgoing ? Colors.black.withAlpha(150) : Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (isOutgoing) 
                                          Padding(
                                            padding: const EdgeInsets.only(left: 3),
                                            child: Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: Colors.black.withAlpha(150),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        
                        // Espaciado entre grupos de fecha
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
  
  // Nueva función para obtener clave de fecha
  String _getDateKey(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (DateUtils.isSameDay(messageDate, today)) {
      return "HOY";
    } else if (DateUtils.isSameDay(messageDate, yesterday)) {
      return "AYER";
    } else {
      return DateFormat('d MMM, yyyy').format(messageDate).toUpperCase();
    }
  }
  
  // Nueva función para convertir clave a fecha
  DateTime _getDateFromKey(String dateKey) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (dateKey == "HOY") {
      return today;
    } else if (dateKey == "AYER") {
      return today.subtract(const Duration(days: 1));
    } else {
      // Intentar parsear formato "d MMM, yyyy"
      try {
        return DateFormat('d MMM, yyyy', 'es').parse(dateKey);
      } catch (e) {
        // Fallback
        return DateTime(1970);
      }
    }
  }
  
  // Construir encabezado desde la clave
  Widget _buildDateHeaderFromKey(String dateKey) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            dateKey,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Borrar mensajes',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '¿Estás seguro de que quieres borrar todos los mensajes de este chat?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Borrar'),
              onPressed: () {
                Navigator.of(context).pop();
                _confirmDeletion();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _confirmDeletion() {
    _processMessageDeletion();
  }
  
  Future<void> _processMessageDeletion() async {
    try {
      await FirebaseMessageService().clearContactMessages(widget.contactName);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensajes borrados'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      logger.e(_tag, "Error al borrar mensajes", e);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al borrar mensajes: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showContactInfoDialog() {
    // Obtener los mensajes filtrados para este contacto
    final allMessages = FirebaseMessageService().getMessages();
    final contactMessages = allMessages.where((message) {
      final recipientMatch = message.recipientName.toLowerCase() == widget.contactName.toLowerCase();
      final senderMatch = message.senderName != null && 
                         message.senderName!.toLowerCase() == widget.contactName.toLowerCase();
      return recipientMatch || senderMatch;
    }).toList();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Información del contacto',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre: ${widget.contactName}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Mensajes: ${contactMessages.length}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}