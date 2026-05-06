import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SetupGuideScreen extends StatelessWidget {
  const SetupGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía de Configuración'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Para que esta aplicación funcione, necesitas habilitar '
                        'los permisos de accesibilidad en tu dispositivo.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Pasos para habilitar el servicio:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStep(
              context,
              number: 1,
              title: 'Abre la configuración del dispositivo',
              description: 'Ve a Ajustes > Accesibilidad',
            ),
            _buildStep(
              context,
              number: 2,
              title: 'Busca "Servicios instalados" o "Servicios descargados"',
              description: 'La ubicación exacta puede variar según tu dispositivo',
            ),
            _buildStep(
              context,
              number: 3,
              title: 'Selecciona "WhatsApp Interceptor"',
              description: 'Debería aparecer en la lista de servicios disponibles',
            ),
            _buildStep(
              context,
              number: 4,
              title: 'Activa el servicio',
              description: 'Mueve el interruptor a la posición "Activado"',
            ),
            _buildStep(
              context,
              number: 5,
              title: 'Confirma los permisos',
              description: 'Acepta el aviso de seguridad que aparecerá',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAccessibilitySettings,
              icon: const Icon(Icons.settings),
              label: const Text('Abrir Configuración de Accesibilidad'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Importante:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'El uso de servicios de accesibilidad para interceptar '
                      'contenido de otras aplicaciones está pensado únicamente para '
                      'propósitos personales y legítimos. Respeta siempre la '
                      'privacidad de los demás.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            child: Text(
              number.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAccessibilitySettings() async {
    const platform = MethodChannel('com.example.whatsapp_interceptor/settings');
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      // Fallback para dispositivos donde el método directo no funciona
      launchUrl(Uri.parse('package:com.android.settings'));
    }
  }
}