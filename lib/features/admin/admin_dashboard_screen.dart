import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme/app_colors.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  
  @override
  void initState() {
    super.initState();
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
                    Positioned.fill(
                      child: Container(
                        color: deepBlack,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, deepBlack.withOpacity(0.6), deepBlack],
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
                            style: TextStyle(color: const Color(0xFFFFD700).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3),
                          ),
                          Text(
                            'Admin $userName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black87, offset: Offset(3, 3), blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(width: 48, height: 3, color: const Color(0xFFFFD700)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // HERRAMIENTAS ADMINISTRATIVAS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('HERRAMIENTAS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
                    Text('GESTIÓN DE MÓDULOS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    TextButton.icon(
                      onPressed: () => _showCreateModuleDialog(context, api),
                      icon: const Icon(Icons.add, color: Color(0xFFFFD700), size: 16),
                      label: const Text('Nuevo', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              
              FutureBuilder<List<Map<String, dynamic>>>(
                future: api.getModules(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                  }
                  final modules = snapshot.data ?? [];
                  if (modules.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('No hay módulos creados.', style: TextStyle(color: Colors.white54)),
                    );
                  }
                  return Column(
                    children: modules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final mod = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminModuleCard(
                          index: idx,
                          title: mod['name'] as String,
                          description: mod['description'] as String,
                          onTap: () {
                            // Can show options to edit/delete in the future
                          },
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

  Future<void> _showCreateModuleDialog(BuildContext context, ApiClient api) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Crear Módulo', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await api.createModule(nameCtrl.text.trim(), descCtrl.text.trim());
                if (mounted) setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({required this.icon, required this.label, required this.color, required this.onTap});

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
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminModuleCard({required this.index, required this.title, required this.description, required this.onTap});

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
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(description, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12), maxLines: 1),
                ],
              ),
            ),
            Icon(Icons.more_vert, color: Colors.white.withOpacity(0.4), size: 20),
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
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFD700).withOpacity(pulseAlpha), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.3), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), size.width * 0.8, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _AdminGlowPainter oldDelegate) => pulseAlpha != oldDelegate.pulseAlpha;
}
