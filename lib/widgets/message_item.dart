import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:intl/intl.dart';

class MessageItem extends StatelessWidget {
  final WhatsAppMessage message;
  final Function()? onDelete;
  
  const MessageItem({
    Key? key,
    required this.message,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getAvatarColor(message.recipientName),
                        child: Text(
                          _getInitials(message.recipientName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.recipientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              message.recipientType == 'group' ? 'Grupo' : 'Contacto',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                message.content,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (onDelete != null) 
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    // Generar un color basado en el nombre para tener avatares consistentes
    // Usamos una forma diferente para calcular el hash que evita posibles problemas de nulabilidad
    int hash = 0;
    if (name.isNotEmpty) {
      for (int codeUnit in name.codeUnits) {
        hash = (hash + codeUnit) % 1000000007; // Un número primo grande para evitar overflow
      }
    }
    
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[hash % colors.length];
  }
  
  String _getInitials(String name) {
    if (name.isEmpty) {
      return '?';
    }
    
    // Caso especial para números
    if (name.startsWith('+')) {
      return name.length >= 3 ? name.substring(1, 3) : name;
    }
    
    // Primera versión simple que toma los primeros dos caracteres
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    } else {
      return name.toUpperCase();
    }
  }
}