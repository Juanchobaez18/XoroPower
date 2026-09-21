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
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // El onAuthStateChange listener disparará notifyListeners()
    } catch (e) {
      throw Exception('Credenciales incorrectas o error de conexión.');
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> register(String name, String email, String password) async {
    await init();
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (res.user != null) {
        // Guardar perfil en la tabla users
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'name': name,
          'role': 'student',
        });
      }
    } catch (e) {
      throw Exception('El correo ya está registrado o hubo un error.');
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

  // --- USERS (Admin) ---
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    await init();
    try {
      final data = await _supabase
          .from('users')
          .select()
          .neq('role', 'admin');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetch users: $e');
      return [];
    }
  }
}
