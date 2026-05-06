// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/services/accessibility_service.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/services/auth_service.dart';
import 'package:whatsapp_interceptor/screens/contacts_screen.dart';
import 'package:whatsapp_interceptor/screens/setup_guide_screen.dart';
import 'package:whatsapp_interceptor/screens/activation_screen.dart';
import 'package:whatsapp_interceptor/widgets/stats_widget.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:whatsapp_interceptor/services/app_visibility_service.dart'; // Nueva importación
import 'package:whatsapp_interceptor/screens/notes_app_screen.dart'; // Nueva importación

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _tag = "HomeScreen";
  bool _isAccessibilityServiceRunning = false;
  bool _isLoading = true;
  bool _showVisibilityDialog = false;  // Para diálogo de confirmación
  Timer? _autoUpdateTimer;

  // Colores de WhatsApp
  final Color _whatsappGreen = const Color(0xFF128C7E);
  final Color _whatsappLightGreen = const Color(0xFF25D366);
  final Color _whatsappDarkGreen = const Color(0xFF075E54);

  @override
  void initState() {
    super.initState();
    _initializeServices();
    
    // Escuchar cambios en autenticación
    authService.authStateStream.listen((isAuthenticated) {
      if (!isAuthenticated && mounted) {
        // Mostrar alerta y redirigir a la pantalla de activación
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Acceso Revocado'),
            content: const Text('Tu código de acceso ha sido desactivado. Contacta al administrador.'),
            actions: [
              TextButton(
                child: const Text('Aceptar'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ActivationScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await accessibilityService.init();
      await firebaseMessageService.init();
      
      // Inicializar servicio de visibilidad
      await appVisibilityService.init();
      logger.d(_tag, "Servicio de visibilidad inicializado");

      // Verificar el estado inicial
      _updateServiceStatus();

      // Escuchar cambios de estado
      accessibilityService.serviceStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _isAccessibilityServiceRunning = status;
            _isLoading = false;
          });
          
          logger.d(_tag, "Estado del servicio de accesibilidad cambiado: $status");
        }
      });

      // Configurar actualización automática cada 3 segundos
      _startAutoUpdate();

      accessibilityService.messageStream.listen((messageData) {
        _handleInterceptedMessage(messageData);
      });
    } catch (e) {
      logger.e(_tag, 'Error en la inicialización', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para iniciar la actualización automática
  void _startAutoUpdate() {
    // Cancelar timer existente si hay alguno
    _autoUpdateTimer?.cancel();
    
    // Crear un nuevo timer que se ejecuta cada 3 segundos
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _updateServiceStatus();
      } else {
        timer.cancel(); // Cancelar si el widget ya no está montado
      }
    });
    
    logger.d(_tag, "Actualización automática iniciada");
  }

  Future<void> _updateServiceStatus() async {
    try {
      final isAccessibilityRunning = await accessibilityService.checkServiceRunning();

      if (mounted) {
        logger.d(_tag, "Verificación del servicio: isAccessibilityRunning=$isAccessibilityRunning");
        
        // Solo actualizar el estado si ha cambiado para evitar renders innecesarios
        if (_isAccessibilityServiceRunning != isAccessibilityRunning) {
          setState(() {
            _isAccessibilityServiceRunning = isAccessibilityRunning;
            _isLoading = false;
          });
          
          logger.d(_tag, "Estado actualizado a: $isAccessibilityRunning");
        }
      }
    } catch (e) {
      logger.e(_tag, 'Error al verificar estado de los servicios', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleInterceptedMessage(Map<String, dynamic> messageData) {
    try {
      logger.d(_tag, 'Mensaje interceptado: ${messageData["content"]}');
    } catch (e) {
      logger.e(_tag, 'Error al procesar mensaje', e);
    }
  }

  void _openAccessibilitySettings() async {
    try {
      await accessibilityService.openAccessibilitySettings();
      
      // Después de abrir la configuración, programar verificaciones
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _updateServiceStatus();
      });
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _updateServiceStatus();
      });
      
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _updateServiceStatus();
      });
      
    } catch (e) {
      logger.e(_tag, 'Error al abrir configuración', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al abrir la configuración de accesibilidad'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }
  
  // Mostrar diálogo de confirmación para activar el modo de camuflaje
  void _showCamouflageModeDialog() {
    setState(() {
      _showVisibilityDialog = true;
    });
  }
  
  // Activar el modo de camuflaje
  void _activateCamouflageMode() async {
    try {
      await appVisibilityService.setInvisible(true);
      
      if (mounted) {
        setState(() {
          _showVisibilityDialog = false;
        });
        
        // Navegar a la pantalla de notas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NotesAppScreen()),
        );
      }
    } catch (e) {
      logger.e(_tag, 'Error al activar modo de camuflaje', e);
      if (mounted) {
        setState(() {
          _showVisibilityDialog = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al activar el modo de camuflaje'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: _whatsappDarkGreen,
          title: const Text('WhatsApp Interceptor'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_whatsappGreen),
              ),
              const SizedBox(height: 16),
              const Text(
                'Iniciando servicios...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: _whatsappDarkGreen,
            title: const Text('WhatsApp Interceptor'),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _updateServiceStatus,
                tooltip: 'Actualizar estado',
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetupGuideScreen()),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.grey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.security,
                              color: _whatsappLightGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Estado del Servicio', // Título más corto
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isAccessibilityServiceRunning 
                                      ? _whatsappGreen.withAlpha(50) 
                                      : Colors.red.withAlpha(50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isAccessibilityServiceRunning ? Icons.check_circle : Icons.error,
                                  color: _isAccessibilityServiceRunning ? _whatsappLightGreen : Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _isAccessibilityServiceRunning ? 'Servicio activo' : 'Servicio inactivo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isAccessibilityServiceRunning ? _whatsappLightGreen : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openAccessibilitySettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAccessibilityServiceRunning 
                                  ? _whatsappGreen 
                                  : Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              _isAccessibilityServiceRunning 
                                  ? 'Configurar' 
                                  : 'Activar servicio',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const StatsWidget(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.contacts),
                          label: const Text('Ver contactos'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ContactsScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _whatsappGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 3,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Nuevo botón para activar el modo de camuflaje
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility_off),
                          label: const Text('Modo Camuflaje'),
                          onPressed: _showCamouflageModeDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Diálogo de confirmación para activar el modo camuflaje
        if (_showVisibilityDialog)
          Container(
            color: Colors.black.withAlpha(179), // Cambiado de withOpacity a withAlpha
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Activar Modo Camuflaje',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'La aplicación se ocultará como un bloc de notas. Para volver a la aplicación original, deberás hacer 10 clics en el título de cualquier nota.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showVisibilityDialog = false;
                              });
                            },
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: _activateCamouflageMode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                            ),
                            child: const Text('Activar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}