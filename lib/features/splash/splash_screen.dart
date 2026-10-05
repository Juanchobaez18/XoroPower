import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  int _slideActual = 0;

  late AnimationController _glowController;
  late AnimationController _progressController;
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();
    _startSequence();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _progressController.animateTo(0.33, curve: Curves.fastOutSlowIn);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  Future<void> _startSequence() async {
    // Inicializar sesión y base de datos local en segundo plano
    final api = ref.read(apiClientProvider);
    await api.init();

    await Future.delayed(const Duration(milliseconds: 4500));
    if (mounted) {
      setState(() => _slideActual = 1);
      _progressController.animateTo(0.66, curve: Curves.fastOutSlowIn);
    }

    await Future.delayed(const Duration(milliseconds: 4800));
    if (mounted) {
      setState(() => _slideActual = 2);
      _progressController.animateTo(1.0, curve: Curves.fastOutSlowIn);
    }

    await Future.delayed(const Duration(milliseconds: 5500));
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _progressController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Stack(
        children: [
          // Border and Radial Glows
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final pulseAlpha =
                  0.4 + (_glowController.value * 0.3); // 0.4 to 0.7
              return CustomPaint(
                size: Size.infinite,
                painter: _GlowPainter(pulseAlpha),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                // Image
                Expanded(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.9, end: 1.05),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      key: ValueKey(_slideActual),
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Image.asset(
                        'assets/images/maracas_splash.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(5, 5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    children: [
                      TextSpan(
                        text: 'XORO',
                        style: TextStyle(color: Color(0xFF0055FF)),
                      ),
                      TextSpan(
                        text: 'PO',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'WER',
                        style: TextStyle(color: Color(0xFFFF0033)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle (slide 1 and 2)
                AnimatedOpacity(
                  opacity: _slideActual >= 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: _slideActual >= 1
                      ? Column(
                          children: [
                            const Text(
                              'APRENDE MARACAS LLANERAS',
                              style: TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xFFFF0033),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Text(
                                  '  JUGANDO  ',
                                  style: TextStyle(
                                    color: Color(0xFF0055FF),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 5,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x800055FF),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF0055FF),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox(height: 40),
                ),

                const SizedBox(height: 16),

                // Info Box (slide 2)
                AnimatedOpacity(
                  opacity: _slideActual >= 2 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: _slideActual >= 2
                      ? Container(
                          decoration: BoxDecoration(
                            color: const Color(0x66000000),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0055FF), Color(0xFFFF0033)],
                              ),
                            ),
                            padding: const EdgeInsets.all(1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xCC000000),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0055FF),
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '💡',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Hacia una experiencia\n',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '100% interactiva.',
                                                style: TextStyle(
                                                  color: Color(0xFF0055FF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Próximamente, xoropower evolucionará para convertirse en tu tutor personal, capaz de analizar tus movimientos y guiarte paso a paso en la ejecución perfecta de cada ejercicio propuesto.',
                                          style: TextStyle(
                                            color: Color(0xFFB0B0B0),
                                            fontSize: 13,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(height: 120),
                ),

                const SizedBox(height: 24),

                // Progress Bar
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progressController.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0055FF),
                                Colors.white,
                                Color(0xFFFF0033),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Loading Text
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    final str = "LOADING...";
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(str.length, (index) {
                        final val = (_textController.value * 10).toInt();
                        final isRed = val == index;
                        final isBlue = val - 1 == index;
                        final color = isRed
                            ? const Color(0xFFFF0033)
                            : isBlue
                            ? const Color(0xFF0055FF)
                            : const Color(0xFF666666);
                        return Text(
                          str[index],
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: (isRed || isBlue)
                                ? [
                                    Shadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final double pulseAlpha;
  _GlowPainter(this.pulseAlpha);

  @override
  void paint(Canvas canvas, Size size) {
    // Left Glow (Blue)
    final bluePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0055FF).withOpacity(pulseAlpha * 0.6),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.1, size.height * 0.35),
              radius: size.width * 0.8,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.35),
      size.width * 0.8,
      bluePaint,
    );

    // Right Glow (Red)
    final redPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF0033).withOpacity(pulseAlpha * 0.6),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.9, size.height * 0.35),
              radius: size.width * 0.8,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.35),
      size.width * 0.8,
      redPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      pulseAlpha != oldDelegate.pulseAlpha;
}
