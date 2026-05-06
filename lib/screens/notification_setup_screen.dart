// lib/screens/notification_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:whatsapp_interceptor/services/incoming_message_detector.dart';

class NotificationSetupScreen extends StatefulWidget {
  const NotificationSetupScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSetupScreen> createState() => _NotificationSetupScreenState();
}

class _NotificationSetupScreenState extends State<NotificationSetupScreen> {
  bool _isLoading = true;
  bool _hasAccess = false;
  
  @override
  void initState() {
    super.initState();
    _checkNotificationAccess();
  }
  
  Future<void> _checkNotificationAccess() async {
    try {
      // Reemplazamos checkNotificationAccess por checkServiceRunning
      final hasAccess = await incomingMessageDetector.checkServiceRunning();
      
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar acceso a notificaciones: $e');
      }
      if (mounted) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _openNotificationSettings() async {
    try {
      await incomingMessageDetector.openNotificationSettings();
    } catch (e) {
      if (kDebugMode) {
        print('Error al abrir configuración de notificaciones: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir la configuración de notificaciones'),
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Configuración de notificaciones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para poder interceptar mensajes entrantes, la aplicación necesita acceso a las notificaciones de WhatsApp.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _hasAccess ? Icons.check_circle : Icons.error,
                                color: _hasAccess ? Colors.green : Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Estado de acceso a notificaciones',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _hasAccess
                                ? 'El acceso a notificaciones está habilitado. Podrás interceptar mensajes entrantes.'
                                : 'El acceso a notificaciones no está habilitado. No podrás interceptar mensajes entrantes.',
                            style: TextStyle(
                              color: _hasAccess ? Colors.green : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _openNotificationSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasAccess ? Colors.grey[800] : Colors.green,
                              ),
                              child: Text(_hasAccess ? 'Cambiar configuración' : 'Habilitar acceso'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instrucciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text('1. Haz clic en "Habilitar acceso".'),
                          SizedBox(height: 8),
                          Text('2. Busca "WhatsApp Interceptor" en la lista.'),
                          SizedBox(height: 8),
                          Text('3. Activa el interruptor para permitir el acceso a notificaciones.'),
                          SizedBox(height: 8),
                          Text('4. Regresa a la aplicación.'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Nota: Este acceso solo se utiliza para leer las notificaciones de WhatsApp y capturar los mensajes entrantes. No accederemos a ninguna otra notificación de tu dispositivo.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: !_isLoading && !_hasAccess
          ? FloatingActionButton.extended(
              onPressed: () async {
                await _openNotificationSettings();
                // Esperar un poco antes de verificar el nuevo estado
                await Future.delayed(const Duration(seconds: 1));
                _checkNotificationAccess();
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Habilitar'),
            )
          : null,
    );
  }
}