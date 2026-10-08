import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme/app_colors.dart';

class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      backgroundColor: AppColors.xoroBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Usuarios Registrados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin_dashboard');
            }
          },
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: api.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0055FF)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar los estudiantes: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text('No hay estudiantes registrados.', style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(
                name: user['name'] ?? 'Sin nombre',
                email: user['email'] ?? 'Sin correo',
                role: user['role'] ?? 'student',
                progress: user['progress'] ?? 'Módulo Básico - Lección 1',
              );
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String progress;

  const _UserCard({required this.name, required this.email, required this.role, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0055FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0055FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF0055FF), fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      progress,
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0055FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(color: Color(0xFF0055FF), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
