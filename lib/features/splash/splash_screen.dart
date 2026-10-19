import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  bool _isMuted = false; // Audio siempre activo por defecto
  bool _needsUserInteractionForAudio = false;
  bool _isPlaying = true;
  bool _hasNavigated = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _fallbackTimer;

  late AnimationController _glowController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _initializeVideoAndApp();
  }

  Future<void> _initializeVideoAndApp() async {
    // 1. Inicializar sesión de Supabase y API en segundo plano
    try {
      final api = ref.read(apiClientProvider);
      await api.init();
    } catch (e) {
      debugPrint('Error al inicializar sesión en SplashScreen: $e');
    }

    // 2. Temporizador de seguridad (máximo 45s por si el video no responde)
    _fallbackTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && !_hasNavigated) {
        _navigateNext();
      }
    });

    // 3. Inicializar el reproductor de video con assets/INDIGENA.mp4
    try {
      final controller = VideoPlayerController.asset('assets/INDIGENA.mp4');
      _controller = controller;

      await controller.initialize();

      if (!mounted) return;

      // En Web los navegadores bloquean el autoplay con sonido antes de interactuar.
      // Iniciamos silenciados para que el video NUNCA se congele y comience a moverse de inmediato.
      await controller.setVolume(0.0);
      await controller.setLooping(false);
      await controller.play();

      controller.addListener(_videoListener);

      setState(() {
        _isVideoInitialized = true;
        _isPlaying = true;
        _isMuted = true;
        _needsUserInteractionForAudio = true;
      });

      _fadeController.forward();
      _resetControlsTimer();
    } catch (e) {
      debugPrint('Error al cargar video assets/INDIGENA.mp4: $e');
      if (mounted) {
        setState(() {
          _hasVideoError = true;
        });
        // Si no se pudo reproducir, avanza tras 4 segundos
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && !_hasNavigated) {
            _navigateNext();
          }
        });
      }
    }
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (mounted) {
      final isCurrentlyPlaying = controller.value.isPlaying;
      if (isCurrentlyPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isCurrentlyPlaying;
        });
      }
    }

    // Detectar cuando el video ha terminado para avanzar automáticamente
    final position = controller.value.position;
    final duration = controller.value.duration;

    if (controller.value.isCompleted ||
        (duration > Duration.zero &&
            position >= duration - const Duration(milliseconds: 200))) {
      _navigateNext();
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (mounted) setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _showControls = true;
        _controlsTimer?.cancel();
      } else {
        controller.play();
        _resetControlsTimer();
      }
      _isPlaying = controller.value.isPlaying;
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isMuted = !_isMuted;
      _needsUserInteractionForAudio = false;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    _resetControlsTimer();
  }

  void _unmuteAudio() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    controller.setVolume(1.0);
    if (!controller.value.isPlaying) {
      controller.play();
    }
    if (mounted) {
      setState(() {
        _isMuted = false;
        _needsUserInteractionForAudio = false;
        _isPlaying = true;
      });
    }
    _resetControlsTimer();
  }

  void _navigateNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _fallbackTimer?.cancel();
    _controlsTimer?.cancel();

    _controller?.removeListener(_videoListener);
    _controller?.pause();

    final api = ref.read(apiClientProvider);
    if (api.isAuthenticated) {
      context.go(api.isAdmin ? '/admin_dashboard' : '/dashboard');
    } else {
      context.go('/login');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controlsTimer?.cancel();
    _glowController.dispose();
    _fadeController.dispose();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Listener(
        onPointerDown: (_) {
          if (_isMuted || _needsUserInteractionForAudio) {
            _unmuteAudio();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo con resplandor ambiental animado
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final pulseAlpha = 0.25 + (_glowController.value * 0.25);
                return CustomPaint(
                  size: Size.infinite,
                  painter: _VideoGlowPainter(pulseAlpha),
                );
              },
            ),

            // Contenido principal: Video o Fallback
            if (_isVideoInitialized && _controller != null)
              _buildVideoPlayerContent()
            else if (_hasVideoError)
              _buildErrorFallback()
            else
              _buildLoadingState(),

            // Banner interactivo si el navegador restringió el audio inicial
            if (_needsUserInteractionForAudio && _isVideoInitialized)
              Positioned(
                bottom: 120,
                left: 20,
                right: 20,
                child: Center(
                  child: GestureDetector(
                    onTap: _unmuteAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0055FF), Color(0xFFFF0033)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x990055FF),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Toca para activar el sonido del video 🔊',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Capa de controles superiores e inferiores (Alineados y responsivos)
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const Spacer(),
                        if (_isVideoInitialized && _controller != null)
                          _buildBottomVideoControls(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón de audio / silencio
        if (_isVideoInitialized)
          InkWell(
            onTap: _toggleMute,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isMuted
                      ? const Color(0xFFFF0033).withOpacity(0.6)
                      : const Color(0xFF0055FF).withOpacity(0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isMuted
                        ? const Color(0xFFFF0033).withOpacity(0.2)
                        : const Color(0xFF0055FF).withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _isMuted ? Colors.white70 : const Color(0xFF0055FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMuted ? 'Silenciado · Toca para activar' : 'Audio activado 🔊',
                    style: TextStyle(
                      color: _isMuted ? Colors.white70 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const SizedBox(width: 48),

        // Logo XOROPOWER
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(3, 3),
                  blurRadius: 10,
                ),
              ],
            ),
            children: [
              TextSpan(text: 'XORO', style: TextStyle(color: Color(0xFF0055FF))),
              TextSpan(text: 'PO', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'WER', style: TextStyle(color: Color(0xFFFF0033))),
            ],
          ),
        ),

        // Botón Saltar
        InkWell(
          onTap: _navigateNext,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0055FF), Color(0xFFFF0033)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x660055FF),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saltar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayerContent() {
    final controller = _controller!;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Center(
      child: FadeTransition(
        opacity: _fadeController,
        child: GestureDetector(
          onTap: () {
            _resetControlsTimer();
            _togglePlayPause();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 960 : double.infinity,
              maxHeight: size.height * 0.78,
            ),
            margin: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 12,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0055FF).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0055FF).withOpacity(0.25),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: const Color(0xFFFF0033).withOpacity(0.15),
                  blurRadius: 36,
                  spreadRadius: -6,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Reproductor de video ajustado a su aspecto
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),

                // Botón central de Play/Pausa que se desvanece
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomVideoControls() {
    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;
    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xCC0D0D12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de progreso personalizada
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    if (width > 0 && duration.inMilliseconds > 0) {
                      final tapPos = details.localPosition.dx.clamp(0.0, width);
                      final fraction = tapPos / width;
                      final targetMs = (fraction * duration.inMilliseconds).toInt();
                      controller.seekTo(Duration(milliseconds: targetMs));
                    }
                  },
                  child: Container(
                    height: 20,
                    color: Colors.transparent, // Facilita el tap
                    alignment: Alignment.center,
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0055FF), Color(0xFFFF0033)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x800055FF),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 6),

            // Tiempos e indicador de contenido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      color: Color(0xFF0055FF),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'XOROPOWER · INTRODUCCIÓN A LAS MARACAS LLANERAS',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0055FF).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0055FF)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'INICIANDO EXPERIENCIA...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/maracas_splash.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'BIENVENIDO A XOROPOWER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cargando contenido interactivo...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _VideoGlowPainter extends CustomPainter {
  final double pulseAlpha;
  _VideoGlowPainter(this.pulseAlpha);

  @override
  void paint(Canvas canvas, Size size) {
    // Resplandor azul superior izquierdo
    final bluePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0055FF).withOpacity(pulseAlpha * 0.45),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.3),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.3),
      size.width * 0.7,
      bluePaint,
    );

    // Resplandor rojo inferior derecho
    final redPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF0033).withOpacity(pulseAlpha * 0.4),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.7),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.7),
      size.width * 0.7,
      redPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoGlowPainter oldDelegate) =>
      pulseAlpha != oldDelegate.pulseAlpha;
}
