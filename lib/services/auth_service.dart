import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _tag = "AuthService";

  // Clave para almacenar el código de activación en SharedPreferences
  static const String _activationCodeKey = 'activation_code';
  static const String _deviceIdKey = 'device_id'; // Para almacenar ID del dispositivo

  // Stream para notificar cambios en el estado de autenticación
  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateStream => _authStateController.stream;

  // Para cancelar los listeners cuando ya no son necesarios
  StreamSubscription? _codeStatusSubscription;

  // Firestore reference
  late FirebaseFirestore _firestore;

  /// Inicializa el servicio de autenticación
  Future<bool> init() async {
    try {
      _firestore = FirebaseFirestore.instance;

      // Verificar autenticación existente
      final result = await checkAuthentication();
      logger.d(_tag, 'Servicio de autenticación inicializado. Autenticado: $result');
      return true;
    } catch (e) {
      logger.e(_tag, 'Error al inicializar servicio de autenticación', e);
      return false;
    }
  }

  /// Obtener código guardado
  Future<String?> getSavedCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activationCodeKey);
  }

  /// Obtener ID del dispositivo
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generar un ID único si no existe
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// Verificar si el código sigue activo
  Future<bool> verifyActivationCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('activation_codes')
          .doc(code)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return data['active'] == true;
      }
      return false;
    } catch (e) {
      logger.e(_tag, 'Error al verificar código de activación', e);
      return false;
    }
  }

  /// Activar un dispositivo con un código
  Future<String> activateDevice(String code) async {
    try {
      final deviceId = await getDeviceId();
      final ref = _firestore.collection('activation_codes').doc(code);
      final snapshot = await ref.get();

      // Si el código no existe o no está activo
      if (!snapshot.exists) {
        logger.w(_tag, 'Código inválido: $code');
        return 'Código inválido';
      }

      final data = snapshot.data() as Map<String, dynamic>;
      if (data['active'] != true) {
        logger.w(_tag, 'Código desactivado: $code');
        return 'Código desactivado';
      }

      // Verificar dispositivos registrados
      List<String> devices = [];
      if (data.containsKey('devices') && data['devices'] is List) {
        devices = List<String>.from(data['devices']);
      }

      // Si el dispositivo ya está registrado
      if (devices.contains(deviceId)) {
        // Guardar código localmente
        await _saveActivationCode(code);
        // Iniciar monitoreo del código
        _startCodeMonitoring(code);
        logger.d(_tag, 'Dispositivo ya activado con código: $code');
        return 'success'; // Ya está activado
      }

      // Si ya hay 2 dispositivos
      if (devices.length >= 2) {
        logger.w(_tag, 'Código ya utilizado en el máximo de dispositivos: $code');
        return 'Código ya utilizado en el máximo de dispositivos permitidos';
      }

      // Agregar el dispositivo
      devices.add(deviceId);
      await ref.update({'devices': devices});

      // También agregamos el registro a sync_records si no existe
      final syncRef = _firestore.collection('sync_records').doc(deviceId);
      await syncRef.set({
        'deviceId': deviceId,
        'lastSync': FieldValue.serverTimestamp(),
        'status': 'active',
        'activationCode': code
      }, SetOptions(merge: true));

      // Guardar código localmente
      await _saveActivationCode(code);

      // Iniciar monitoreo del código
      _startCodeMonitoring(code);

      logger.d(_tag, 'Dispositivo activado con código: $code');
      return 'success';
    } catch (e) {
      logger.e(_tag, 'Error al activar dispositivo', e);
      return 'Error de conexión: $e';
    }
  }

  /// Guardar código de activación localmente
  Future<void> _saveActivationCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activationCodeKey, code);
    logger.d(_tag, 'Código guardado localmente: $code');
  }

  /// Monitorear cambios en el estado del código
  void _startCodeMonitoring(String code) {
    // Cancelar cualquier suscripción previa
    _codeStatusSubscription?.cancel();

    // Iniciar nueva suscripción
    _codeStatusSubscription = _firestore
        .collection('activation_codes')
        .doc(code)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final isActive = data['active'] == true;

        if (!isActive) {
          logger.w(_tag, 'Código desactivado remotamente: $code');
          _forceLogout();
        }
      } else {
        logger.w(_tag, 'Código eliminado remotamente: $code');
        _forceLogout();
      }
    }, onError: (e) {
      logger.e(_tag, 'Error al monitorear código', e);
    });

    logger.d(_tag, 'Monitoreo de código iniciado: $code');
  }

  /// Forzar cierre de sesión
  Future<void> _forceLogout() async {
    // Limpiar datos locales
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activationCodeKey);

    // Cancelar suscripciones
    _codeStatusSubscription?.cancel();

    // Notificar cambio de estado
    _authStateController.add(false);

    logger.d(_tag, 'Sesión cerrada forzosamente');
  }

  /// Verificar autenticación al iniciar la app
  Future<bool> checkAuthentication() async {
    final code = await getSavedCode();
    if (code == null) {
      logger.d(_tag, 'No hay código guardado');
      return false;
    }

    final isActive = await verifyActivationCode(code);
    if (isActive) {
      _startCodeMonitoring(code);
      logger.d(_tag, 'Código verificado y activo: $code');
      return true;
    } else {
      await _forceLogout();
      logger.w(_tag, 'Código guardado no válido: $code');
      return false;
    }
  }

  /// Cerrar recursos al finalizar
  void dispose() {
    _codeStatusSubscription?.cancel();
    _authStateController.close();
    logger.d(_tag, 'Servicio de autenticación finalizado');
  }
}

final authService = AuthService();