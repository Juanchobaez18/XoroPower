import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final List<List<String>> _messages = [
    ["El ritmo es el alma del llano.", "Sigue practicando tu pulso."],
    ["La maraca es tu voz.", "Domina el escobillao."],
    ["Disciplina y pasión.", "Sigue adelante, músico."],
    ["Cada práctica cuenta.", "La perfección llega con constancia."],
  ];
  int _msgIdx = 0;
  Timer? _msgTimer;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _msgTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) setState(() => _msgIdx = (_msgIdx + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final userName = api.currentName;
    final esAdmin = api.isAdmin;

    const deepBlack = Color(0xFF030305);
    const cardBg = Color(0xFF0E0E16);

    return Scaffold(
      backgroundColor: AppColors.xoroBlack,
      body: Stack(
        children: [
          // Background Glows
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final pulseAlpha = 0.25 + (_glowController.value * 0.25);
              return CustomPaint(
                size: Size.infinite,
                painter: _HomeGlowPainter(pulseAlpha),
              );
            },
          ),

          // Main Content
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // HERO SECTION
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/home.png',
                        fit: BoxFit.cover,
                      ),
                    ),
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
                            'BIENVENIDO',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            userName.split(' ').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
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
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 3,
                                color: const Color(0xFF0055FF),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 8,
                                height: 3,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 28,
                                height: 3,
                                color: const Color(0xFFFF0033),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // MOTIVATIONAL MESSAGE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: Container(
                    key: ValueKey<int>(_msgIdx),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0055FF).withOpacity(0.4),
                            const Color(0xFFFF0033).withOpacity(0.4),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Text('🎵', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _messages[_msgIdx][0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _messages[_msgIdx][1],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ACCESOS RÁPIDOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'ACCESO RÁPIDO',
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
                      child: _QuickAccessCard(
                        icon: Icons.map_outlined,
                        label: 'Progreso',
                        color: const Color(0xFF0055FF),
                        onTap: () => context.go('/progress'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAccessCard(
                        icon: Icons.book_outlined,
                        label: 'Categorías',
                        color: const Color(0xFFFFAA00),
                        onTap: () => context.go('/categories'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAccessCard(
                        icon: Icons.person_outline,
                        label: 'Perfil',
                        color: const Color(0xFFFF0033),
                        onTap: () => context.go('/profile'),
                      ),
                    ),
                  ],
                ),
              ),

              if (esAdmin) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.add_outlined,
                          label: 'Crear Ejercicio',
                          color: const Color(0xFFFFD700),
                          onTap: () => context.go('/admin_add_exercise'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // TUS MÓDULOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TUS MÓDULOS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    if (esAdmin)
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

              // MÓDULOS DINÁMICOS
              FutureBuilder<List<Map<String, dynamic>>>(
                future: api.getModules(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD700),
                      ),
                    );
                  }
                  final modules = snapshot.data ?? [];
                  if (modules.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No hay módulos disponibles.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return Column(
                    children: modules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final mod = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PremiumModuleCard(
                          index: idx,
                          title: mod['name'] as String,
                          description: mod['description'] as String,
                          onTap: () {
                            context.push('/module/${mod['id']}');
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

  Future<void> _showCreateModuleDialog(
    BuildContext context,
    ApiClient api,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Crear Módulo',
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
              if (nameCtrl.text.isNotEmpty) {
                await api.createModule(
                  nameCtrl.text.trim(),
                  descCtrl.text.trim(),
                );
                if (mounted) setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Crear',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
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
        aspectRatio: 1,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
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

class _PremiumModuleCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PremiumModuleCard({
    required this.index,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOdd = index % 2 != 0;
    final accentColor = isOdd
        ? const Color(0xFF0055FF)
        : const Color(0xFFFF0033);

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
              child: Text(
                '$index',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: accentColor.withOpacity(0.5), blurRadius: 8),
                  ],
                ),
              ),
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
            Icon(
              Icons.chevron_right,
              color: accentColor.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGlowPainter extends CustomPainter {
  final double pulseAlpha;
  _HomeGlowPainter(this.pulseAlpha);

  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0055FF).withOpacity(pulseAlpha),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(0, size.height * 0.25),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawCircle(
      Offset(0, size.height * 0.25),
      size.width * 0.7,
      bluePaint,
    );

    final redPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF0033).withOpacity(pulseAlpha),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width, size.height * 0.25),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawCircle(
      Offset(size.width, size.height * 0.25),
      size.width * 0.7,
      redPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeGlowPainter oldDelegate) =>
      pulseAlpha != oldDelegate.pulseAlpha;
}
