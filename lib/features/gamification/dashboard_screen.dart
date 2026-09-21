import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                child: Text('🤠', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, Estudiante', style: theme.textTheme.titleLarge),
                  Text('¡Sigue con tu racha!', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                    SizedBox(width: 4),
                    Text('3', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 40),
          Text('Módulos Disponibles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, color: theme.colorScheme.secondary),
              ),
              title: const Text('Ritmo Básico'),
              subtitle: const Text('Aprende los fundamentos del ritmo.'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          )
        ],
      ),
    );
  }
}
