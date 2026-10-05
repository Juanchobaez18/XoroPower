import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme/app_colors.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Future<List<Map<String, dynamic>>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _modulesFuture = ref.read(apiClientProvider).getModules();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final userName = api.currentName;

    const deepBlack = Color(0xFF030305);

    return Scaffold(
      backgroundColor: AppColors.xoroBlack,
      body: Stack(
        children: [
          // Background Glows
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final pulseAlpha = 0.15 + (_glowController.value * 0.15);
              return CustomPaint(
                size: Size.infinite,
                painter: _AdminGlowPainter(pulseAlpha),
              );
            },
          ),

          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // HERO SECTION
              SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: deepBlack)),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              deepBlack.withOpacity(0.6),
                              deepBlack,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PANEL DE CONTROL',
                            style: TextStyle(
                              color: const Color(0xFFFFD700).withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'Admin $userName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(3, 3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 48,
                            height: 3,
                            color: const Color(0xFFFFD700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // HERRAMIENTAS ADMINISTRATIVAS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'HERRAMIENTAS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _AdminActionCard(
                        icon: Icons.video_call_outlined,
                        label: 'Grabar\nLección',
                        color: const Color(0xFFFF0033),
                        onTap: () => context.go('/admin_add_exercise'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminActionCard(
                        icon: Icons.people_outline,
                        label: 'Ver\nUsuarios',
                        color: const Color(0xFF0055FF),
                        onTap: () => context.go('/admin_users'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // GESTIÓN DE MÓDULOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GESTIÓN DE MÓDULOS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCreateModuleDialog(context, api),
                      icon: const Icon(
                        Icons.add,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                      label: const Text(
                        'Nuevo',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _modulesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD700),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No se pudieron cargar los módulos: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }
                  final modules = snapshot.data ?? [];
                  if (modules.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No hay módulos creados.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return Column(
                    children: modules.asMap().entries.map((entry) {
                      final mod = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminModuleCard(
                          title: mod['name'] as String,
                          description: mod['description']?.toString() ?? '',
                          onTap: () {
                            context.push('/module/${mod['id']}');
                          },
                          onEdit: () =>
                              _showModuleDialog(context, api, module: mod),
                          onDelete: () => _deleteModule(context, api, mod),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateModuleDialog(BuildContext context, ApiClient api) =>
      _showModuleDialog(context, api);

  Future<void> _showModuleDialog(
    BuildContext context,
    ApiClient api, {
    Map<String, dynamic>? module,
  }) async {
    final nameCtrl = TextEditingController(
      text: module?['name']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: module?['description']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          module == null ? 'Crear Módulo' : 'Editar Módulo',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Descripción',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio.')),
                );
                return;
              }
              try {
                if (module == null) {
                  await api.createModule(name, descCtrl.text.trim());
                } else {
                  await api.updateModule(
                    module['id'].toString(),
                    name,
                    descCtrl.text.trim(),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (error) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('No se pudo guardar: $error')),
                  );
                }
              }
            },
            child: Text(
              module == null ? 'Crear' : 'Guardar',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    if (saved == true && mounted) {
      setState(() {
        _modulesFuture = api.getModules();
      });
    }
  }

  Future<void> _deleteModule(
    BuildContext context,
    ApiClient api,
    Map<String, dynamic> module,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Eliminar módulo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${module['name'] ?? 'Módulo'}", todas sus lecciones y el progreso de los estudiantes? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await api.deleteModule(module['id'].toString());
      if (!context.mounted) return;
      setState(() {
        _modulesFuture = api.getModules();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Módulo eliminado.')));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.2,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminModuleCard({
    required this.title,
    required this.description,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFFD700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.4)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.folder_outlined, color: accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Gestionar módulo',
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar módulo')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar módulo')),
              ],
              icon: Icon(
                Icons.more_vert,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminGlowPainter extends CustomPainter {
  final double pulseAlpha;
  _AdminGlowPainter(this.pulseAlpha);

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFD700).withOpacity(pulseAlpha),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.3),
              radius: size.width * 0.8,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width * 0.8,
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AdminGlowPainter oldDelegate) =>
      pulseAlpha != oldDelegate.pulseAlpha;
}
