import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/audio_service.dart';
import '../../core/vision/pose_detector_service.dart';
import 'camera_view.dart';

class PantallaRitmo extends ConsumerStatefulWidget {
  final String titulo;
  const PantallaRitmo({super.key, required this.titulo});

  @override
  ConsumerState<PantallaRitmo> createState() => _PantallaRitmoState();
}

class NoteState {
  final int timeMs;
  final String hand;
  bool hit = false;
  bool missed = false;

  NoteState({required this.timeMs, required this.hand});
}

class _PantallaRitmoState extends ConsumerState<PantallaRitmo> with TickerProviderStateMixin {
  List<NoteState> _notes = [];
  bool _isPlaying = false;
  bool _isFinished = false;
  
  DateTime? _startTime;
  int _elapsedMs = 0;
  Timer? _gameLoop;
  
  int _score = 0;
  int _combo = 0;
  
  String _lastFeedback = "¡PREPÁRATE!";
  Color _feedbackColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadExercise();
    ref.read(audioServiceProvider).init();
  }

  Future<void> _loadExercise() async {
    final api = ref.read(apiClientProvider);
    final exercises = await api.getExercises();
    
    if (exercises.isNotEmpty) {
      // Tomamos el último ejercicio grabado para probar
      final lastEx = exercises.last;
      final rawNotes = lastEx['notas'] as List<dynamic>? ?? [];
      
      setState(() {
        _notes = rawNotes.map((n) {
          final noteMap = n as Map<String, dynamic>;
          return NoteState(
            timeMs: (noteMap['time_ms'] as num).toInt(),
            hand: noteMap['hand'] as String,
          );
        }).toList();
        
        // Ordenamos por tiempo por si acaso
        _notes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      });
    }
  }

  void _startGame() {
    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay notas en esta lección. Graba una primero.')),
      );
      return;
    }
    
    setState(() {
      _isPlaying = true;
      _startTime = DateTime.now();
      _score = 0;
      _combo = 0;
      _lastFeedback = "¡A BAILAR!";
      _feedbackColor = Colors.greenAccent;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) { // ~60fps
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      setState(() {
        _elapsedMs = now.difference(_startTime!).inMilliseconds;
      });

      _checkMisses();
      
      // Chequeo de fin de canción (última nota + 2 segundos)
      if (_notes.isNotEmpty && _elapsedMs > _notes.last.timeMs + 2000) {
        _finishGame();
      }
    });
  }
  
  void _finishGame() {
    _gameLoop?.cancel();
    setState(() {
      _isPlaying = false;
      _isFinished = true;
      _lastFeedback = "¡LECCIÓN COMPLETADA!";
      _feedbackColor = const Color(0xFFFFD700);
    });
  }

  void _checkMisses() {
    for (var note in _notes) {
      if (!note.hit && !note.missed) {
        // Si el tiempo actual sobrepasó el tiempo de la nota + 300ms de tolerancia
        if (_elapsedMs > note.timeMs + 300) {
          note.missed = true;
          _combo = 0;
          _showFeedback("¡FALLO!", Colors.grey);
          ref.read(audioServiceProvider).playMiss();
        }
      }
    }
  }

  void _onShake(HandSide side) {
    if (!_isPlaying) return;
    
    final handString = side == HandSide.right ? 'derecha' : 'izquierda';
    
    // Buscar la primera nota no hit/miss de esa mano
    NoteState? targetNote;
    for (var note in _notes) {
      if (!note.hit && !note.missed && note.hand == handString) {
        targetNote = note;
        break;
      }
    }
    
    if (targetNote != null) {
      final diff = (_elapsedMs - targetNote.timeMs).abs();
      
      if (diff <= 300) {
        // HIT!
        targetNote.hit = true;
        _combo++;
        _score += 10 * _combo;
        
        ref.read(audioServiceProvider).playHit();
        
        if (diff <= 100) {
          _showFeedback("¡PERFECTO!", const Color(0xFFFFD700));
        } else {
          _showFeedback("¡BIEN!", side == HandSide.right ? const Color(0xFFFF0033) : const Color(0xFF0055FF));
        }
      } else if (_elapsedMs < targetNote.timeMs - 300) {
        // Agitó demasiado temprano, pero si está muy lejos no penalizamos tanto visualmente, solo reseteamos combo
        // Aquí podríamos hacer lógica de Early Miss, pero lo mantenemos simple.
      }
    }
  }

  void _showFeedback(String text, Color color) {
    setState(() {
      _lastFeedback = text;
      _feedbackColor = color;
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Cámara en el fondo
          Positioned.fill(
            child: CameraView(onShake: _onShake),
          ),
          
          // 2. Filtro oscuro 
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          
          // 3. UI Superpuesta: Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () {
                      _gameLoop?.cancel();
                      context.pop();
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PUNTOS: \$_score',
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      if (_combo > 1)
                        Text(
                          '\$_combo COMBO',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. El Canvas del MotorRitmo (Notas cayendo)
          if (_isPlaying)
            Positioned.fill(
              child: CustomPaint(
                painter: _RhythmHighwayPainter(
                  notes: _notes,
                  elapsedMs: _elapsedMs,
                  fallDurationMs: 2000, // Tiempo que tarda una nota en caer desde arriba hasta la zona de hit
                ),
              ),
            ),
            
          // 5. Hit Zone Guides
          if (_isPlaying || _isFinished)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HitZone(color: const Color(0xFF0055FF), label: 'IZQ'), // Left
                  _HitZone(color: const Color(0xFFFF0033), label: 'DER'), // Right
                ],
              ),
            ),

          // 6. Feedback Text Center
          if (_isPlaying)
            Center(
              child: AnimatedOpacity(
                opacity: _lastFeedback.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _lastFeedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
              ),
            ),

          // 7. Botón de Iniciar / Fin de Lección
          if (!_isPlaying)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isFinished) ...[
                    const Text(
                      '¡LECCIÓN COMPLETADA!',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puntuación final: \$_score',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _isFinished ? () => context.pop() : _startGame,
                    child: Text(
                      _isFinished ? 'Volver al Menú' : 'INICIAR PISTA',
                      style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900),
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

class _HitZone extends StatelessWidget {
  final Color color;
  final String label;

  const _HitZone({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        color: color.withOpacity(0.1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

class _RhythmHighwayPainter extends CustomPainter {
  final List<NoteState> notes;
  final int elapsedMs;
  final int fallDurationMs;

  _RhythmHighwayPainter({
    required this.notes,
    required this.elapsedMs,
    required this.fallDurationMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double hitZoneY = size.height - 120; // Aproximadamente donde están las HitZones
    final double startY = 0;
    final double highwayLength = hitZoneY - startY;

    final double leftLaneX = size.width * 0.25;
    final double rightLaneX = size.width * 0.75;

    // Pintar los carriles (decorativo)
    final lanePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(leftLaneX, 0), Offset(leftLaneX, size.height), lanePaint);
    canvas.drawLine(Offset(rightLaneX, 0), Offset(rightLaneX, size.height), lanePaint);

    // Pintar las notas
    for (var note in notes) {
      if (note.hit || note.missed) continue; // No dibujar si ya la pasamos

      // Calcula cuánto falta para que llegue al hitZone
      final int timeToHit = note.timeMs - elapsedMs;
      
      // Si está más lejos que el fallDuration, aún no entra a la pantalla
      if (timeToHit > fallDurationMs) continue;
      
      // Si ya pasó por mucho, tampoco se dibuja (se maneja en _checkMisses, pero porsiacaso)
      if (timeToHit < -500) continue;

      // Calcular posición Y:
      // Cuando timeToHit == fallDurationMs -> Y = startY
      // Cuando timeToHit == 0 -> Y = hitZoneY
      final double progress = 1.0 - (timeToHit / fallDurationMs);
      final double currentY = startY + (highwayLength * progress);

      final double currentX = note.hand == 'izquierda' ? leftLaneX : rightLaneX;
      final Color noteColor = note.hand == 'izquierda' ? const Color(0xFF0055FF) : const Color(0xFFFF0033);

      final paint = Paint()
        ..color = noteColor
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Dibujar la nota (Maraca)
      canvas.drawCircle(Offset(currentX, currentY), 24, paint);
      canvas.drawCircle(Offset(currentX, currentY), 24, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RhythmHighwayPainter oldDelegate) {
    return oldDelegate.elapsedMs != elapsedMs;
  }
}
