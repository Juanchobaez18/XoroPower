import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _initialized = false;
  bool _isAdmin = false;
  String _currentName = 'Estudiante';
  String? _currentEmail;

  Future<void> init() async {
    if (_initialized) return;

    // Verificar si ya hay una sesión activa
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _currentEmail = session.user.email;
      await _loadUserProfile(session.user.id);
    }

    // Escuchar los cambios de autenticación para notificar al enrutador
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _currentEmail = session.user.email;
        await _loadUserProfile(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _isAdmin = false;
        _currentName = 'Estudiante';
        _currentEmail = null;
        notifyListeners();
      }
    });

    _initialized = true;
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('name, role')
          .eq('id', userId)
          .single();

      _currentName = data['name'] ?? 'Estudiante';
      _isAdmin = data['role'] == 'admin';
    } catch (e) {
      debugPrint('Error loading profile: $e');
      // Fallback
      _isAdmin = false;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await init();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      // El onAuthStateChange listener disparará notifyListeners()
    } catch (e) {
      if (e is AuthException) {
        throw Exception(e.message);
      }
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> register(String name, String email, String password) async {
    await init();
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      // El perfil en public.users se creará automáticamente vía un Trigger en Supabase.
    } catch (e) {
      if (e is AuthException) {
        throw Exception(e.message);
      }
      throw Exception(e.toString());
    }
  }

  bool get isAuthenticated => _supabase.auth.currentSession != null;
  bool get isAdmin => _isAdmin;
  String get currentName => _currentName;
  String? get currentEmail => _currentEmail;

  // --- MODULES ---
  Future<List<Map<String, dynamic>>> getModules() async {
    await init();
    try {
      final data = await _supabase.from('modules').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetch modules: $e');
      return [];
    }
  }

  Future<void> createModule(String name, String description) async {
    await init();
    try {
      await _supabase.from('modules').insert({
        'name': name,
        'description': description,
      });
    } catch (e) {
      debugPrint('Error create module: $e');
      throw Exception('Error al crear módulo');
    }
  }

  // --- EXERCISES ---
  Future<void> saveExercise(Map<String, dynamic> exercisePayload) async {
    await init();
    try {
      await _supabase.from('exercises').insert(exercisePayload);
    } catch (e) {
      debugPrint('Error save exercise: $e');
      throw Exception('Error al guardar ejercicio');
    }
  }

  Future<void> updateExercise(
    String id,
    Map<String, dynamic> exercisePayload,
  ) async {
    await init();
    try {
      await _supabase.from('exercises').update(exercisePayload).eq('id', id);
    } catch (e) {
      debugPrint('Error update exercise: $e');
      throw Exception('Error al actualizar ejercicio');
    }
  }

  Future<void> deleteExercise(String id) async {
    await init();
    try {
      await _supabase.from('exercises').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error delete exercise: $e');
      throw Exception('Error al eliminar ejercicio');
    }
  }

  Future<List<Map<String, dynamic>>> getExercises() async {
    await init();
    try {
      final data = await _supabase.from('exercises').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetch exercises: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getExerciseById(String id) async {
    await init();
    try {
      final data = await _supabase
          .from('exercises')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetch exercise: $e');
      return null;
    }
  }

  // --- USERS (Admin) ---
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    await init();
    try {
      final data = await _supabase.from('users').select().neq('role', 'admin');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetch users: $e');
      return [];
    }
  }

  // --- PROGRESS ---
  Future<void> guardarProgreso(String idEjercicio, int puntuacion) async {
    if (_supabase.auth.currentUser == null) return;
    try {
      final completado = puntuacion >= 70;

      // Consultamos si ya existe progreso para este ejercicio
      final userId = _supabase.auth.currentUser!.id;
      final existingData = await _supabase
          .from('progreso_usuario')
          .select()
          .eq('id_usuario', userId)
          .eq('id_ejercicio', idEjercicio)
          .maybeSingle();

      int mejorPuntuacion = puntuacion;
      int vecesIntentado = 1;

      if (existingData != null) {
        final currentMax = existingData['puntuacion_mas_alta'] as int? ?? 0;
        mejorPuntuacion = puntuacion > currentMax ? puntuacion : currentMax;
        vecesIntentado = (existingData['veces_intentado'] as int? ?? 0) + 1;
      }

      await _supabase.from('progreso_usuario').upsert({
        'id_usuario': userId,
        'id_ejercicio': idEjercicio,
        'completado': completado || (existingData?['completado'] == true),
        'puntuacion_mas_alta': mejorPuntuacion,
        'porcentaje_avance': mejorPuntuacion,
        'veces_intentado': vecesIntentado,
        'timestamp_ultimo_intento': DateTime.now().toIso8601String(),
        if (completado && existingData?['timestamp_completado'] == null)
          'timestamp_completado': DateTime.now().toIso8601String(),
      }, onConflict: 'id_usuario, id_ejercicio');

      await registrarUso();
    } catch (e) {
      debugPrint('Error al guardar progreso: $e');
    }
  }

  Future<void> registrarUso() async {
    if (_supabase.auth.currentUser == null) return;
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('rachas_usuario').upsert({
        'id_usuario': userId,
        'ultima_actividad': DateTime.now().toIso8601String(),
        'dias_seguidos': 1,
      });
    } catch (e) {
      debugPrint('Error al registrar uso: $e');
    }
  }
}
