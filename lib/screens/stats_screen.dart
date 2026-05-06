// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/services/export_service.dart';
import 'package:whatsapp_interceptor/services/message_storage_service.dart';
import 'package:whatsapp_interceptor/widgets/app_version_widget.dart';
import 'package:whatsapp_interceptor/widgets/stats_widget.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        title: const Text('Estadísticas'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const StatsWidget(),
            
            // Nota sobre la privacidad y el uso de datos
            Card(
              color: Colors.grey[900]?.withAlpha(204),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.amber[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nota sobre privacidad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.amber[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Todos los mensajes interceptados se almacenan únicamente '
                      'en tu dispositivo y no se comparten con nadie. '
                      'Esta aplicación está diseñada para uso personal.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recuerda respetar la privacidad de los demás al usar '
                      'esta aplicación. El uso indebido puede violar '
                      'la ley en algunos países.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Funcionalidades de limpieza (si es necesario)
            // Exportar todos los mensajes
            Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.ios_share,
                  color: Colors.blue,
                ),
                title: Text(
                  'Exportar todos los mensajes',
                  style: TextStyle(
                    color: Colors.grey[300],
                  ),
                ),
                subtitle: Text(
                  'Guardar copia de seguridad en formato JSON',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                onTap: () => _exportAllMessages(context),
              ),
            ),
            
            // Borrar todos los mensajes
            Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: Text(
                  'Borrar todos los mensajes',
                  style: TextStyle(
                    color: Colors.grey[300],
                  ),
                ),
                subtitle: Text(
                  'Esta acción no se puede deshacer',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Versión de la aplicación
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  const AppVersionWidget(
                    textColor: Colors.grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© ${DateTime.now().year} WhatsApp Interceptor',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Exportar todos los mensajes como archivo JSON
  Future<void> _exportAllMessages(BuildContext context) async {
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
            ),
            const SizedBox(width: 20),
            const Text(
              'Exportando mensajes...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Intentar exportar
    final success = await exportService.exportAllMessages();
    
    // Cerrar diálogo de carga
    if (context.mounted) {
      Navigator.pop(context);
      
      // Mostrar resultado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Mensajes exportados correctamente' 
              : 'No se pudieron exportar los mensajes',
          ),
          backgroundColor: success ? Colors.green[800] : Colors.red[800],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '¿Borrar todos los mensajes?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción eliminará permanentemente todos los mensajes interceptados. '
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              // Eliminar todos los mensajes
              await messageStorageService.clearAllMessages();
              if (context.mounted) {
                Navigator.pop(context);
                
                // Mostrar confirmación
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Todos los mensajes han sido eliminados'),
                    backgroundColor: Colors.red[700],
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'Borrar',
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }
}