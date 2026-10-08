import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/audio_service.dart';
import '../../core/vision/pose_detector_service.dart';
import 'camera_view.dart';
import 'lesson_staff.dart';

class PantallaRitmo extends ConsumerStatefulWidget {
  final String titulo;
  final String? exerciseId;
  const PantallaRitmo({super.key, required this.titulo, this.exerciseId});

  @override
  ConsumerState<PantallaRitmo> createState() => _PantallaRitmoState();
}

class NoteState extends StaffNote {
  NoteState({
    required super.timeMs,
    required super.hand,
    required super.direction,
  });
}

class _PantallaRitmoState extends ConsumerState<PantallaRitmo>
    with SingleTickerProviderStateMixin {
  List<NoteState> _notes = [];
  bool _isLoadingExercise = true;
  bool _isPreparingGame = false;
  String? _exerciseLoadError;
  String? _cameraError;
  String? _cameraDetectionStatus;
  bool _cameraReady = false;
  bool _isPlaying = false;
  bool _isFinished = false;
  int _lessonRun = 0;

  Stopwatch? _gameClock;
  int _elapsedMs = 0;
  Ticker? _ticker;
  int _lastMetronomeBeat = -1;

  int _score = 0;
  int _combo = 0;
  int _correctHits = 0;
  final List<String> _movementIssues = [];
  int _tempoBpm = 120;
  String _exerciseTitle = 'Lección';
  String? _loadedExerciseId;

  String _lastFeedback = "¡PREPÁRATE!";
  Color _feedbackColor = Colors.white;

  int get _hitWindowMs =>
      (60000 / _tempoBpm * 0.3).round().clamp(80, 200).toInt();
  int get _perfectWindowMs =>
      (60000 / _tempoBpm * 0.1).round().clamp(40, 80).toInt();
  int get _approvalPercent =>
      _notes.isEmpty ? 0 : (_correctHits * 100 / _notes.length).round();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadExercise();
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;

    final elapsedMs = _gameClock!.elapsedMilliseconds;
    final currentBeat = (elapsedMs / (60000 / _tempoBpm)).floor();
    if (currentBeat > _lastMetronomeBeat) {
      ref.read(audioServiceProvider).playMetronome();
      _lastMetronomeBeat = currentBeat;
    }
    setState(() {
      _elapsedMs = elapsedMs;
    });

    _checkMisses();

    // Chequeo de fin de canción (última nota + 2 segundos)
    if (_notes.isNotEmpty && _elapsedMs > _notes.last.timeMs + 2000) {
      _finishGame();
    }
  }

  Future<void> _loadExercise() async {
    try {
      final api = ref.read(apiClientProvider);
      final requested = widget.exerciseId;
      final Map<String, dynamic>? exercise;
      if (requested != null) {
        exercise = await api.getExerciseById(requested);
      } else {
        final exercises = await api.getExercises();
        exercise = exercises.isEmpty ? null : exercises.last;
      }
      if (!mounted) return;
      if (exercise == null) {
        setState(() {
          _exerciseLoadError = 'No se encontró el ejercicio solicitado.';
          _isLoadingExercise = false;
        });
        return;
      }

      List<dynamic> rawNotes = [];
      dynamic rawNotesData = exercise['notas'] ?? exercise['secuencia_notas'];
      if (rawNotesData is String) {
        final decoded = jsonDecode(rawNotesData);
        if (decoded is! List) {
          throw const FormatException('La secuencia de notas no es una lista.');
        }
        rawNotes = decoded;
      } else if (rawNotesData is List) {
        rawNotes = rawNotesData;
      }
      final firstNote = rawNotes.isEmpty
          ? null
          : Map<String, dynamic>.from(rawNotes.first as Map);
      final rawTempo =
          firstNote?['tempo_bpm'] ??
          exercise['tempo_bpm'] ??
          exercise['tempoBpm'];
      final savedTempo = rawTempo is num
          ? rawTempo.toInt()
          : int.tryParse(rawTempo?.toString() ?? '');

      final tempo = savedTempo != null && savedTempo > 0 ? savedTempo : 120;
      final notes = rawNotes.map((rawNote) {
        final noteMap = Map<String, dynamic>.from(rawNote as Map);
        final parsedNote = StaffNote.fromJson(noteMap);
        return NoteState(
          timeMs: StaffNote.quantizeTimeMs(parsedNote.timeMs, tempo),
          hand: parsedNote.hand,
          direction: parsedNote.direction,
        );
      }).toList();
      notes.sort((a, b) {
        final timeComparison = a.timeMs.compareTo(b.timeMs);
        return timeComparison != 0 ? timeComparison : a.hand.compareTo(b.hand);
      });
      final loadedExercise = exercise;
      final loadedExerciseId = loadedExercise['id']?.toString();
      final loadedExerciseTitle =
          loadedExercise['titulo']?.toString() ?? widget.titulo;

      setState(() {
        _loadedExerciseId = loadedExerciseId;
        _exerciseTitle = loadedExerciseTitle;
        _tempoBpm = tempo;
        _notes = notes;
        _isLoadingExercise = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _exerciseLoadError = 'No se pudo preparar el ejercicio: $error';
          _isLoadingExercise = false;
        });
      }
    }
  }

  void _changeTempo(int bpm) {
    if (bpm == _tempoBpm) return;
    final timeScale = _tempoBpm / bpm;
    final rescaledNotes = _notes
        .map(
          (note) => NoteState(
            timeMs: StaffNote.quantizeTimeMs(
              (note.timeMs * timeScale).round(),
              bpm,
            ),
            hand: note.hand,
            direction: note.direction,
          ),
        )
        .toList();
    setState(() {
      _tempoBpm = bpm;
      _notes = rescaledNotes;
    });
  }

  Future<void> _startGame() async {
    if (_isLoadingExercise) return;
    if (!_cameraReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cameraError ?? 'Espera a que la cámara esté lista para iniciar.',
          ),
        ),
      );
      return;
    }
    if (_exerciseLoadError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_exerciseLoadError!)));
      return;
    }
    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ejercicio aún no tiene notas.')),
      );
      return;
    }

    setState(() {
      _isPreparingGame = true;
      _isFinished = false;
      _lessonRun++;
      _lastFeedback = "¡PREPÁRATE! 4...";
      _feedbackColor = Colors.orangeAccent;
    });
    try {
      await ref.read(audioServiceProvider).init();
    } catch (error) {
      debugPrint('Audio local no disponible; se continúa sin sonido: $error');
    }
    if (!mounted) return;

    int count = 4;
    ref.read(audioServiceProvider).playMetronome();

    Timer.periodic(Duration(milliseconds: (60000 / _tempoBpm).round()), (
      timer,
    ) {
      count--;
      if (count > 0) {
        if (mounted) {
          setState(() {
            _lastFeedback = "¡PREPÁRATE! $count...";
          });
          ref.read(audioServiceProvider).playMetronome();
        }
      } else {
        timer.cancel();
        if (mounted && _isPreparingGame) {
          setState(() {
            _isPreparingGame = false;
            _isPlaying = true;
            _gameClock = Stopwatch()..start();
            _lastMetronomeBeat = 0;
            _score = 0;
            _combo = 0;
            _correctHits = 0;
            _movementIssues.clear();
            _elapsedMs = 0;
            for (final note in _notes) {
              note.hit = false;
              note.missed = false;
            }
            _lastFeedback = "¡A BAILAR!";
            _feedbackColor = Colors.greenAccent;
          });

          ref.read(audioServiceProvider).playMetronome();

          _ticker?.start();
        }
      }
    });
  }

  void _finishGame() async {
    _ticker?.stop();
    _gameClock?.stop();
    ref.read(audioServiceProvider).stopMetronome();
    setState(() {
      _isPlaying = false;
      _isFinished = true;
      _lastFeedback = "¡LECCIÓN COMPLETADA!";
      _feedbackColor = const Color(0xFFFFD700);
    });

    // Guardar progreso usando ApiClient
    final api = ref.read(apiClientProvider);
    if (_loadedExerciseId != null) {
      try {
        await api.guardarProgreso(_loadedExerciseId!, _approvalPercent);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar el progreso: $error')),
          );
        }
      }
    }
  }

  void _checkMisses() {
    for (var note in _notes) {
      if (!note.hit && !note.missed) {
        if (_elapsedMs > note.timeMs + _hitWindowMs) {
          note.missed = true;
          _combo = 0;
          _showFeedback('¡FALLO!', Colors.redAccent);
          ref.read(audioServiceProvider).playMiss();
        }
      }
    }
  }

  void _onShake(DetectedMotion motion) {
    if (!_isPlaying) return;
    final currentMs = _gameClock?.elapsedMilliseconds ?? _elapsedMs;

    final handString = motion.hand == HandSide.right ? 'derecha' : 'izquierda';
    final directionString = motion.direction == MotionDirection.up
        ? 'arriba'
        : 'abajo';

    // Buscar la primera nota no hit/miss de esa mano
    NoteState? targetNote;
    for (var note in _notes) {
      if (!note.hit &&
          !note.missed &&
          note.hand == handString &&
          (targetNote == null ||
              (note.timeMs - currentMs).abs() <
                  (targetNote.timeMs - currentMs).abs())) {
        targetNote = note;
      }
    }

    if (targetNote != null) {
      final diff = (currentMs - targetNote.timeMs).abs();

      if (diff <= _hitWindowMs && targetNote.direction == directionString) {
        // HIT!
        targetNote.hit = true;
        _combo++;
        _correctHits++;
        _score += 10 * _combo;

        ref.read(audioServiceProvider).playHit();

        if (diff <= _perfectWindowMs) {
          _showFeedback('¡PERFECTO!', Colors.greenAccent);
        } else {
          _showFeedback('¡BIEN!', Colors.greenAccent);
        }
      } else if (diff <= 300) {
        _combo = 0;
        if (targetNote.direction != directionString) {
          _movementIssues.add(
            '${_formatBeat(targetNote.timeMs)} · ${handString.toUpperCase()} hizo ${directionString.toUpperCase()}, se esperaba ${targetNote.direction.toUpperCase()}.',
          );
          _showFeedback(
            'DIRECCIÓN: ${targetNote.direction.toUpperCase()}',
            Colors.redAccent,
          );
        } else {
          _movementIssues.add(
            '${_formatBeat(targetNote.timeMs)} · ${handString.toUpperCase()} llegó fuera del pulso.',
          );
          _showFeedback('FUERA DE TIEMPO', Colors.redAccent);
        }
      } else if (currentMs < targetNote.timeMs - 300) {
        _combo = 0;
        _movementIssues.add(
          '${_formatBeat(currentMs)} · ${handString.toUpperCase()} hizo el movimiento antes del pulso.',
        );
        _showFeedback('MUY TEMPRANO', Colors.redAccent);
      }
    } else {
      _combo = 0;
      _movementIssues.add(
        '${_formatBeat(currentMs)} · Movimiento extra: ${handString.toUpperCase()} ${directionString.toUpperCase()}, sin golpe esperado.',
      );
      _showFeedback('MOVIMIENTO NO ESPERADO', Colors.redAccent);
    }
  }

  String _formatBeat(int timeMs) {
    final beat = StaffNote.beatIndexForTime(timeMs, _tempoBpm);
    return 'Compás ${beat ~/ 4 + 1} · pulso ${beat % 4 + 1}';
  }

  Widget _buildEvaluationSummary() {
    final missedCount = _notes.where((note) => note.missed).length;
    final passed = _approvalPercent >= 70;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21160D),
        border: Border.all(
          color: passed ? const Color(0xFF55C86A) : const Color(0xFFE53935),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            passed
                ? 'APROBADO · $_approvalPercent%'
                : 'NO APROBADO · $_approvalPercent%',
            style: TextStyle(
              color: passed ? const Color(0xFF8DF19A) : const Color(0xFFFF8A80),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Aciertos: $_correctHits/${_notes.length} · Fallos: $missedCount · Movimientos incorrectos/extra: ${_movementIssues.length}. Se aprueba con 70% de los golpes esperados.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 20),
          const Text(
            'DETALLE DEL EJERCICIO',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          ..._notes.map((note) {
            final status = note.hit
                ? 'Correcto'
                : note.missed
                ? 'No realizado'
                : 'Pendiente';
            final color = note.hit
                ? const Color(0xFF8DF19A)
                : note.missed
                ? const Color(0xFFFF8A80)
                : Colors.white70;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${_formatBeat(note.timeMs)} · ${note.hand.toUpperCase()} ${note.direction == 'arriba' ? '↑ ARRIBA' : '↓ ABAJO'} · $status',
                style: TextStyle(color: color, fontSize: 11),
              ),
            );
          }),
          if (_movementIssues.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'MOVIMIENTOS A CORREGIR',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontWeight: FontWeight.w900,
              ),
            ),
            ..._movementIssues
                .take(12)
                .map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      issue,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            if (_movementIssues.length > 12)
              Text(
                'Y ${_movementIssues.length - 12} movimientos más.',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
          ],
        ],
      ),
    );
  }

  void _showFeedback(String text, Color color) {
    setState(() {
      _lastFeedback = text;
      _feedbackColor = color;
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _gameClock?.stop();
    ref.read(audioServiceProvider).stopMetronome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        title: Text(
          _exerciseTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _ticker?.stop();
            _gameClock?.stop();
            ref.read(audioServiceProvider).stopMetronome();
            context.pop();
          },
        ),
        actions: [
          Center(
            child: Text(
              '$_score pts  ',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          if (_isLoadingExercise)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Cargando ejercicio y partitura...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (_exerciseLoadError != null || _notes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _exerciseLoadError ?? 'Este ejercicio todavía no tiene notas.',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PARTITURA DE LA LECCIÓN',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: [60, 80, 100, 120, 140, 160].contains(_tempoBpm)
                      ? _tempoBpm
                      : 120,
                  dropdownColor: const Color(0xFF171717),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  items: [60, 80, 100, 120, 140, 160]
                      .map(
                        (bpm) => DropdownMenuItem(
                          value: bpm,
                          child: Text('$bpm BPM'),
                        ),
                      )
                      .toList(),
                  onChanged: _isPlaying || _isPreparingGame
                      ? null
                      : (bpm) {
                          if (bpm != null) _changeTempo(bpm);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LessonStaff(
            key: ValueKey(_lessonRun),
            notes: _notes,
            bpm: _tempoBpm,
            currentMs: _isPlaying ? _elapsedMs : -1,
          ),
          const SizedBox(height: 8),
          const Text(
            'Rojo: mano derecha   Azul: mano izquierda   ↑ / ↓: dirección del movimiento',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraView(
                    onShake: _onShake,
                    enableTapSimulation: false,
                    onCameraReady: (ready) {
                      if (!mounted) return;
                      setState(() => _cameraReady = ready);
                    },
                    onCameraError: (error) {
                      if (!mounted) return;
                      setState(() => _cameraError = error);
                    },
                    onDetectionStatus: (status) {
                      if (!mounted || _cameraDetectionStatus == status) return;
                      setState(() => _cameraDetectionStatus = status);
                    },
                  ),
                  ColoredBox(color: Colors.black.withValues(alpha: .08)),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: Text(
                          'CÁMARA · DETECCIÓN DE MANOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isPlaying)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Text(
                        'COMBO $_combo',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _cameraReady
                ? _cameraDetectionStatus ??
                      'Cámara activa: mantén el torso y ambas manos dentro del encuadre.'
                : _cameraError ?? 'Activando cámara...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _cameraReady ? Colors.greenAccent : Colors.orangeAccent,
              fontSize: 12,
            ),
          ),
          if (_isPlaying || _isPreparingGame)
            Text(
              _lastFeedback,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _feedbackColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            )
          else if (_isFinished)
            _buildEvaluationSummary(),
          const SizedBox(height: 10),
          if (_isFinished)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _startGame,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'REPETIR',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'CONTINUAR',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed:
                  _isPlaying ||
                      _isLoadingExercise ||
                      _isPreparingGame ||
                      !_cameraReady
                  ? null
                  : _startGame,
              icon: Icon(
                _isLoadingExercise || _isPreparingGame || !_cameraReady
                    ? Icons.hourglass_empty
                    : Icons.play_arrow,
              ),
              label: Text(
                _isLoadingExercise
                    ? 'CARGANDO EJERCICIO...'
                    : _isPreparingGame
                    ? 'PREPARANDO METRÓNOMO...'
                    : !_cameraReady
                    ? 'ACTIVANDO CÁMARA...'
                    : 'INICIAR LECCIÓN',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}
