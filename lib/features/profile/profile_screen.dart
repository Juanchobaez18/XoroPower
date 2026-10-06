import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/api_client.dart';
import '../exercises/lesson_staff.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<List<Map<String, dynamic>>> _studentExercises;

  @override
  void initState() {
    super.initState();
    _studentExercises = _loadStudentExercises();
  }

  Future<List<Map<String, dynamic>>> _loadStudentExercises() async {
    final api = ref.read(apiClientProvider);
    final modules = await api.getModules();
    final exercises = await api.getExercises();
    final moduleNames = {
      for (final module in modules)
        module['id'].toString(): module['name']?.toString() ?? 'Módulo',
    };
    return exercises.map((exercise) {
      final moduleId = (exercise['modulo_id'] ?? exercise['module_id'])
          ?.toString();
      return {...exercise, 'module_name': moduleNames[moduleId] ?? 'Módulo'};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final userName = api.currentName;
    final userEmail = api.currentEmail ?? 'correo@ejemplo.com';
    final esAdmin = api.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'CUENTA',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'Perfil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),

          // Avatar and Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF0055FF).withOpacity(0.12),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0055FF).withOpacity(0.15),
                        const Color(0xFF0055FF).withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF0055FF).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🤠', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 20),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: esAdmin
                        ? const Color(0xFFFFD700).withOpacity(0.12)
                        : const Color(0xFF0055FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: esAdmin
                          ? const Color(0xFFFFD700).withOpacity(0.35)
                          : const Color(0xFF0055FF).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    esAdmin ? 'ADMINISTRADOR' : 'ESTUDIANTE ACTIVO',
                    style: TextStyle(
                      color: esAdmin
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF0055FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info Rows
          _ProfileInfoRow(
            icon: Icons.person_outline,
            label: 'NOMBRE DE USUARIO',
            value: userName,
          ),
          const SizedBox(height: 8),
          _ProfileInfoRow(
            icon: Icons.mail_outline,
            label: 'CORREO ELECTRÓNICO',
            value: userEmail,
          ),
          if (esAdmin) ...[
            const SizedBox(height: 8),
            const _ProfileInfoRow(
              icon: Icons.admin_panel_settings_outlined,
              label: 'ROL',
              value: 'Administrador — acceso completo a todos los niveles',
            ),
          ],

          const SizedBox(height: 24),

          if (!esAdmin) ...[
            const Text(
              'EJERCICIOS PLANTEADOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _studentExercises,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudieron cargar los ejercicios: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
                final exercises = snapshot.data ?? [];
                if (exercises.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: const Text(
                      'Aún no hay ejercicios planteados. Revisa las categorías para ver las lecciones disponibles.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  );
                }
                return Column(
                  children: exercises
                      .map(
                        (exercise) => _StudentExerciseCard(exercise: exercise),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          if (esAdmin) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/admin_add_exercise'),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  'Crear Ejercicio',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // About Row
          _ProfileMenuRow(
            icon: Icons.info_outline,
            label: 'Acerca de xoropower',
            sub: 'Versión 1.0.0 Stable',
            color: Colors.white.withOpacity(0.5),
          ),

          const SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                api.logout();
              },
              icon: const Icon(Icons.logout, color: Color(0xFFF44336)),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Color(0xFFF44336),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: const Color(0xFFF44336).withOpacity(0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _StudentExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const _StudentExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    dynamic rawNotesData = exercise['notas'] ?? exercise['secuencia_notas'];
    if (rawNotesData is String) {
      try {
        rawNotesData = jsonDecode(rawNotesData);
      } catch (_) {}
    }
    final rawNotes = (rawNotesData as List<dynamic>?) ?? [];
    final notes = rawNotes
        .map(
          (note) => StaffNote.fromJson(Map<String, dynamic>.from(note as Map)),
        )
        .toList();
    final rawTempo =
        (rawNotes.isEmpty ? null : (rawNotes.first as Map)['tempo_bpm']) ??
        exercise['tempo_bpm'];
    final parsedTempo = rawTempo is num
        ? rawTempo.toInt()
        : int.tryParse(rawTempo?.toString() ?? '') ?? 120;
    final tempo = parsedTempo > 0 ? parsedTempo : 120;

    return Card(
      color: const Color(0xFF0D0D0D),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise['titulo']?.toString() ?? 'Ejercicio de ritmo',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${exercise['module_name']} · $tempo BPM · ${notes.length} movimientos',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (exercise['descripcion'] != null) ...[
              const SizedBox(height: 8),
              Text(
                exercise['descripcion'].toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 10),
            if (notes.isNotEmpty)
              LessonStaff(notes: notes, bpm: tempo)
            else
              const Text(
                'Este ejercicio aún no tiene notas.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/instructions/${exercise['id']}'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar ejercicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.1),
            size: 16,
          ),
        ],
      ),
    );
  }
}
