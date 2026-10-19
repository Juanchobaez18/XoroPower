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
  int _cameraRetryKey = 0;
  String _cameraFitMode = 'contain';
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

  void _retryCamera() {
    setState(() {
      _cameraError = null;
      _cameraDetectionStatus = null;
      _cameraReady = false;
      _cameraRetryKey++;
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF11141E),
        border: Border.all(
          color: passed ? const Color(0xFF00E676) : const Color(0xFFFF5252),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (passed ? const Color(0xFF00E676) : const Color(0xFFFF5252))
                .withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (passed ? const Color(0xFF00E676) : const Color(0xFFFF5252))
                      .withOpacity(0.15),
                ),
                child: Icon(
                  passed ? Icons.check_circle : Icons.error,
                  color: passed ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passed ? '¡LECCIÓN APROBADA!' : 'LECCIÓN NO APROBADA',
                      style: TextStyle(
                        color: passed
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      passed
                          ? 'Excelente precisión rítmica y coordinación'
                          : 'Se requiere 70% de aciertos para aprobar el ejercicio',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (passed ? const Color(0xFF00E676) : const Color(0xFFFF5252))
                        .withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '$_approvalPercent%',
                  style: TextStyle(
                    color: passed
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF5252),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              _buildStatCard(
                'Aciertos',
                '$_correctHits/${_notes.length}',
                const Color(0xFF00E676),
                Icons.done_all,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Fallos',
                '$missedCount',
                const Color(0xFFFF5252),
                Icons.close,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Desvíos',
                '${_movementIssues.length}',
                const Color(0xFFFFB74D),
                Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Puntaje',
                '$_score',
                const Color(0xFFFFD700),
                Icons.emoji_events,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          const Text(
            'DETALLE DE GOLPES DE LA LECCIÓN',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _notes.length,
              itemBuilder: (context, i) {
                final note = _notes[i];
                final status = note.hit
                    ? 'A Tiempo'
                    : note.missed
                    ? 'No ejecutado'
                    : 'Pendiente';
                final color = note.hit
                    ? const Color(0xFF00E676)
                    : note.missed
                    ? const Color(0xFFFF5252)
                    : Colors.white54;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatBeat(note.timeMs),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${note.hand.toUpperCase()} (${note.direction == 'arriba' ? '↑ ARRIBA' : '↓ ABAJO'})',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_movementIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            const Text(
              'OBSERVACIONES Y CORRECCIONES',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            ..._movementIssues.take(8).map(
              (issue) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFFFFB74D))),
                    Expanded(
                      child: Text(
                        issue,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_movementIssues.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Y ${_movementIssues.length - 8} observaciones más.',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFF07090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _ticker?.stop();
            _gameClock?.stop();
            ref.read(audioServiceProvider).stopMetronome();
            context.pop();
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0055FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0055FF).withOpacity(0.4),
                ),
              ),
              child: const Text(
                'LECCIÓN',
                style: TextStyle(
                  color: Color(0xFF0055FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _exerciseTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withOpacity(0.15),
                  const Color(0xFFFF8C00).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars,
                  color: Color(0xFFFFD700),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_score PTS',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (_isLoadingExercise)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Cargando ejercicio y partitura...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else if (_exerciseLoadError != null || _notes.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orangeAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _exerciseLoadError ??
                              'Este ejercicio todavía no tiene notas cargadas.',
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    ],
                  ),
                ),

              // Staff Header & Tempo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          color: Color(0xFFFFD700),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'PARTITURA DE LA LECCIÓN',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
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
                            fontSize: 12,
                          ),
                          items: [60, 80, 100, 120, 140, 160]
                              .map(
                                (bpm) => DropdownMenuItem(
                                  value: bpm,
                                  child: Text('⚡ $bpm BPM'),
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              LessonStaff(
                key: ValueKey(_lessonRun),
                notes: _notes,
                bpm: _tempoBpm,
                currentMs: _isPlaying ? _elapsedMs : -1,
              ),
              const SizedBox(height: 10),

              // Legend Badges
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendChip(
                    const Color(0xFFE53935),
                    'Mano derecha (Rojo)',
                  ),
                  _buildLegendChip(
                    const Color(0xFF1E88E5),
                    'Mano izquierda (Azul)',
                  ),
                  _buildLegendChip(
                    const Color(0xFFFFD700),
                    '↑ / ↓ Dirección del movimiento',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Camera Validation Area (Responsive Widescreen Card with 100% Uncropped FOV)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 720;
                  final cameraHeight = isDesktop ? 460.0 : 330.0;
                  final cameraMaxWidth = isDesktop ? 860.0 : double.infinity;

                  return Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: cameraMaxWidth,
                        maxHeight: cameraHeight,
                        minHeight: 280,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07090E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _cameraReady
                              ? const Color(0xFF00E676).withOpacity(0.4)
                              : const Color(0xFF0055FF).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_cameraReady
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF0055FF))
                                .withOpacity(0.12),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraView(
                              key: ValueKey('student-camera-$_cameraRetryKey'),
                              onShake: _onShake,
                              enableTapSimulation: false,
                              fitMode: _cameraFitMode,
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

                            // Retícula / Guías en esquinas
                            const Positioned(
                              top: 14,
                              left: 14,
                              child: _CameraCorner(isTop: true, isLeft: true),
                            ),
                            const Positioned(
                              top: 14,
                              right: 14,
                              child: _CameraCorner(isTop: true, isLeft: false),
                            ),
                            const Positioned(
                              bottom: 14,
                              left: 14,
                              child: _CameraCorner(isTop: false, isLeft: true),
                            ),
                            const Positioned(
                              bottom: 14,
                              right: 14,
                              child: _CameraCorner(isTop: false, isLeft: false),
                            ),

                            // Badge superior izquierdo: Estado de la cámara
                            Positioned(
                              left: 14,
                              top: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _cameraReady
                                        ? const Color(0xFF00E676)
                                        : Colors.orangeAccent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _cameraReady
                                            ? const Color(0xFF00E676)
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _cameraReady
                                          ? 'CÁMARA ACTIVA'
                                          : 'ACTIVANDO CÁMARA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Badge superior derecho: Combo
                            if (_isPlaying && _combo > 1)
                              Positioned(
                                right: 14,
                                top: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFF8C00),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD700)
                                            .withOpacity(0.4),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'COMBO x$_combo',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                            // Inferior izquierdo: Detección de manos
                            Positioned(
                              left: 14,
                              bottom: 14,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 320),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.accessibility_new,
                                      color: Color(0xFF00E5FF),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _cameraDetectionStatus ??
                                            'Mantén torso y maracas en el encuadre',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Inferior derecho: Selector de modo de encuadre (Visión 100% vs Llenar)
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: Tooltip(
                                message: _cameraFitMode == 'contain'
                                    ? 'Cambiar a modo pantalla completa'
                                    : 'Cambiar a visión completa sin recorte',
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _cameraFitMode = _cameraFitMode == 'contain'
                                          ? 'cover'
                                          : 'contain';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFFD700)
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _cameraFitMode == 'contain'
                                              ? Icons.fullscreen
                                              : Icons.fit_screen,
                                          size: 14,
                                          color: const Color(0xFFFFD700),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _cameraFitMode == 'contain'
                                              ? 'Visión 100%'
                                              : 'Llenar',
                                          style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Feedback Banner
              if (_isPlaying || _isPreparingGame)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        key: ValueKey(_lastFeedback),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _feedbackColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _feedbackColor.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          _lastFeedback,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: _feedbackColor.withOpacity(0.5),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_isFinished)
                _buildEvaluationSummary(),

              const SizedBox(height: 16),

              // Bottom Action Buttons
              if (_isFinished)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                        ),
                        onPressed: _startGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'REPETIR LECCIÓN',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFFFD700).withOpacity(0.4),
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
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFFFD700).withOpacity(0.4),
                  ),
                  onPressed: _isPlaying || _isLoadingExercise || _isPreparingGame
                      ? null
                      : _cameraReady
                      ? _startGame
                      : _cameraError != null
                      ? _retryCamera
                      : null,
                  icon: Icon(
                    _isLoadingExercise || _isPreparingGame
                        ? Icons.hourglass_empty
                        : !_cameraReady && _cameraError != null
                        ? Icons.refresh
                        : !_cameraReady
                        ? Icons.hourglass_empty
                        : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  label: Text(
                    _isLoadingExercise
                        ? 'CARGANDO EJERCICIO...'
                        : _isPreparingGame
                        ? 'PREPARANDO METRÓNOMO...'
                        : !_cameraReady && _cameraError != null
                        ? 'REINTENTAR CÁMARA'
                        : !_cameraReady
                        ? 'ACTIVANDO CÁMARA...'
                        : 'INICIAR LECCIÓN',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendChip(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  const _CameraCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
