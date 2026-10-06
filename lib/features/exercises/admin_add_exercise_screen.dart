import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/audio_service.dart';
import '../../core/vision/pose_detector_service.dart';
import 'camera_view.dart';
import 'lesson_staff.dart';

class AdminAddExerciseScreen extends ConsumerStatefulWidget {
  final String? exerciseId;
  final String? moduleId;

  const AdminAddExerciseScreen({super.key, this.exerciseId, this.moduleId});

  @override
  ConsumerState<AdminAddExerciseScreen> createState() =>
      _AdminAddExerciseScreenState();
}

class _AdminAddExerciseScreenState
    extends ConsumerState<AdminAddExerciseScreen> {
  final TextEditingController _titleController = TextEditingController();

  bool _isRecording = false;
  bool _isSaving = false;
  bool _isPreparingRecording = false;
  Stopwatch? _recordingClock;
  Timer? _metronomeTimer;
  int _lastMetronomeBeat = -1;
  int _tempoBpm = 120;
  static const List<int> _tempoOptions = [60, 80, 100, 120, 140, 160];
  int _selectedMeasure = 1;
  int _selectedPulse = 1;
  String _selectedHand = 'derecha';
  String _selectedDirection = 'abajo';

  final List<StaffNote> _recordedNotes = [];

  String _lastActionText = "Listo para grabar";
  Color _statusColor = Colors.white;

  List<Map<String, dynamic>> _modules = [];
  String? _selectedModuleId;
  bool _isEditing = false;
  bool _showCamera = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final api = ref.read(apiClientProvider);
    final modules = await api.getModules();
    final exercise = widget.exerciseId == null
        ? null
        : await api.getExerciseById(widget.exerciseId!);
    List<dynamic> rawNotes = [];
    dynamic rawNotesData = exercise?['notas'] ?? exercise?['secuencia_notas'];
    if (rawNotesData is String) {
      try {
        final decoded = jsonDecode(rawNotesData);
        if (decoded is List) rawNotes = decoded;
      } catch (_) {}
    } else if (rawNotesData is List) {
      rawNotes = rawNotesData;
    }
    final firstNote = rawNotes.isEmpty
        ? null
        : Map<String, dynamic>.from(rawNotes.first as Map);
    final rawTempo = firstNote?['tempo_bpm'] ?? exercise?['tempo_bpm'];
    final savedTempo = rawTempo is num
        ? rawTempo.toInt()
        : int.tryParse(rawTempo?.toString() ?? '');
    if (mounted) {
      setState(() {
        _modules = modules;
        _isEditing = exercise != null;
        _selectedModuleId =
            exercise?['modulo_id']?.toString() ??
            exercise?['module_id']?.toString() ??
            widget.moduleId;
        if (_selectedModuleId == null && _modules.isNotEmpty) {
          _selectedModuleId = _modules.first['id'].toString();
        }
        if (exercise != null) {
          _titleController.text = exercise['titulo']?.toString() ?? '';
          _recordedNotes
            ..clear()
            ..addAll(
              rawNotes.map(
                (note) =>
                    StaffNote.fromJson(Map<String, dynamic>.from(note as Map)),
              ),
            );
          _tempoBpm = savedTempo != null && savedTempo > 0 ? savedTempo : 120;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _metronomeTimer?.cancel();
    _recordingClock?.stop();
    ref.read(audioServiceProvider).stopMetronome();
    super.dispose();
  }

  void _onShakeDetected(DetectedMotion motion) {
    if (!_isRecording || _recordingClock == null) return;

    final elapsedMs = _recordingClock!.elapsedMilliseconds;
    final snappedTimeMs = StaffNote.quantizeTimeMs(elapsedMs, _tempoBpm);
    final hand = motion.hand == HandSide.right ? 'derecha' : 'izquierda';
    if (_recordedNotes.any(
      (note) => note.hand == hand && note.timeMs == snappedTimeMs,
    )) {
      return;
    }

    setState(() {
      _recordedNotes.add(
        StaffNote(
          timeMs: snappedTimeMs,
          hand: hand,
          direction: motion.direction == MotionDirection.up
              ? 'arriba'
              : 'abajo',
        ),
      );
      _sortNotes();

      _lastActionText =
          '${motion.hand == HandSide.right ? 'DERECHA' : 'IZQUIERDA'} · ${motion.direction == MotionDirection.up ? 'ARRIBA' : 'ABAJO'}';
      _statusColor = motion.hand == HandSide.right
          ? const Color(0xFFFF0033)
          : const Color(0xFF0055FF);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isRecording) {
        setState(() {
          _lastActionText = "Grabando... (${_recordedNotes.length} notas)";
          _statusColor = Colors.greenAccent;
        });
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isPreparingRecording) return;
    if (!_isRecording) {
      setState(() => _isPreparingRecording = true);
      try {
        await ref.read(audioServiceProvider).init();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo iniciar el metrónomo: $error'),
            ),
          );
        }
        if (mounted) setState(() => _isPreparingRecording = false);
        return;
      }
      if (!mounted) return;
    }

    setState(() {
      if (_isRecording) {
        // Detener grabación
        _isRecording = false;
        _metronomeTimer?.cancel();
        _recordingClock?.stop();
        ref.read(audioServiceProvider).stopMetronome();
        _lastActionText =
            "Grabación detenida. ${_recordedNotes.length} notas capturadas.";
        _statusColor = Colors.white;
      } else {
        // Iniciar grabación con conteo
        _isPreparingRecording = true;
        _lastActionText = "¡Prepárate! 4...";
        _statusColor = Colors.orangeAccent;

        int count = 4;
        ref.read(audioServiceProvider).playMetronome();
        
        Timer.periodic(Duration(milliseconds: (60000 / _tempoBpm).round()), (timer) {
          count--;
          if (count > 0) {
            if (mounted) {
              setState(() {
                _lastActionText = "¡Prepárate! $count...";
              });
              ref.read(audioServiceProvider).playMetronome();
            }
          } else {
            timer.cancel();
            if (mounted && _isPreparingRecording) {
              setState(() {
                _isPreparingRecording = false;
                _isRecording = true;
                _showCamera = true;
                _recordingClock = Stopwatch()..start();
                _lastMetronomeBeat = 0;
                _lastActionText = "Grabando... ¡Mueve tus manos!";
                _statusColor = Colors.greenAccent;

                ref.read(audioServiceProvider).playMetronome();
                _metronomeTimer = Timer.periodic(
                  const Duration(milliseconds: 16),
                  (_) {
                    final beat = (_recordingClock!.elapsedMilliseconds /
                            (60000 / _tempoBpm))
                        .floor();
                    if (beat > _lastMetronomeBeat) {
                      ref.read(audioServiceProvider).playMetronome();
                      _lastMetronomeBeat = beat;
                    }
                  },
                );
              });
            }
          }
        });
      }
    });
  }

  void _changeTempo(int bpm) {
    if (bpm == _tempoBpm) return;
    final timeScale = _tempoBpm / bpm;
    final rescaledNotes = _recordedNotes
        .map(
          (note) => StaffNote(
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
      _recordedNotes
        ..clear()
        ..addAll(rescaledNotes);
      _sortNotes();
    });
  }

  void _sortNotes() {
    _recordedNotes.sort((a, b) {
      final timeComparison = a.timeMs.compareTo(b.timeMs);
      return timeComparison != 0
          ? timeComparison
          : a.hand.compareTo(b.hand);
    });
  }

  void _addScheduledNote() {
    final beatIndex = (_selectedMeasure - 1) * 4 + _selectedPulse - 1;
    final timeMs = StaffNote.timeForBeat(beatIndex, _tempoBpm);
    final existingIndex = _recordedNotes.indexWhere(
      (note) => note.hand == _selectedHand && note.timeMs == timeMs,
    );
    final note = StaffNote(
      timeMs: timeMs,
      hand: _selectedHand,
      direction: _selectedDirection,
    );

    setState(() {
      if (existingIndex >= 0) {
        _recordedNotes[existingIndex] = note;
      } else {
        _recordedNotes.add(note);
      }
      _sortNotes();
      _lastActionText =
          'Compás $_selectedMeasure · pulso $_selectedPulse · ${_selectedHand.toUpperCase()} ${_selectedDirection.toUpperCase()}';
      _statusColor = _selectedHand == 'derecha'
          ? const Color(0xFFFF0033)
          : const Color(0xFF0055FF);
    });
  }

  void _removeScheduledNote(StaffNote note) {
    setState(() => _recordedNotes.remove(note));
  }

  Future<void> _confirmClearNotes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar notas del ejercicio'),
        content: const Text(
          'Se quitarán todas las notas de la partitura. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar notas'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _recordedNotes.clear());
    }
  }

  Future<void> _saveExercise() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un título para la lección'),
        ),
      );
      return;
    }

    if (_selectedModuleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona o crea un módulo primero'),
        ),
      );
      return;
    }

    if (_recordedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos una nota al ejercicio')),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    setState(() => _isSaving = true);
    try {
      final notes = _recordedNotes
          .map((note) => note.toJson()..['tempo_bpm'] = _tempoBpm)
          .toList();
      final exercisePayload = {
        'titulo': _titleController.text.trim(),
        'modulo_id': _selectedModuleId,
        'notas': notes,
      };
      if (_isEditing) {
        await api.updateExercise(widget.exerciseId!, exercisePayload);
      } else {
        await api.saveExercise({
          ...exercisePayload,
          'creado_el': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Lección actualizada.'
                  : '¡Lección guardada exitosamente!',
            ),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildNoteComposer() {
    const accent = Color(0xFFFFD700);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CREAR NOTA EN EL PENTAGRAMA',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona el compás, el pulso, la mano y la dirección. La nota queda guardada exactamente en ese pulso.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMeasure,
                  dropdownColor: const Color(0xFF171717),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Compás',
                    labelStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    32,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: _isRecording
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedMeasure = value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedPulse,
                  dropdownColor: const Color(0xFF171717),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Pulso (4/4)',
                    labelStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    4,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: _isRecording
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedPulse = value);
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedHand,
                  dropdownColor: const Color(0xFF171717),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mano',
                    labelStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'derecha',
                      child: Text('Derecha · roja'),
                    ),
                    DropdownMenuItem(
                      value: 'izquierda',
                      child: Text('Izquierda · azul'),
                    ),
                  ],
                  onChanged: _isRecording
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedHand = value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDirection,
                  dropdownColor: const Color(0xFF171717),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Movimiento',
                    labelStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'abajo',
                      child: Text('↓ Abajo'),
                    ),
                    DropdownMenuItem(
                      value: 'arriba',
                      child: Text('↑ Arriba'),
                    ),
                  ],
                  onChanged: _isRecording
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedDirection = value);
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isRecording ? null : _addScheduledNote,
              icon: const Icon(Icons.add),
              label: const Text('Añadir / actualizar nota'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledNotesList() {
    final notes = List<StaffNote>.of(_recordedNotes)
      ..sort((a, b) {
        final timeComparison = a.timeMs.compareTo(b.timeMs);
        return timeComparison != 0
            ? timeComparison
            : a.hand.compareTo(b.hand);
      });
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: notes.map((note) {
          final beatIndex = StaffNote.beatIndexForTime(
            note.timeMs,
            _tempoBpm,
          );
          final handColor = note.hand == 'derecha'
              ? const Color(0xFFFF5252)
              : const Color(0xFF448AFF);
          return ListTile(
            dense: true,
            leading: Icon(Icons.music_note, color: handColor),
            title: Text(
              'Compás ${beatIndex ~/ 4 + 1} · pulso ${beatIndex % 4 + 1}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${note.hand.toUpperCase()} · ${note.direction.toUpperCase()}',
              style: TextStyle(color: handColor, fontSize: 11),
            ),
            trailing: IconButton(
              tooltip: 'Quitar nota',
              onPressed: _isRecording
                  ? null
                  : () => _removeScheduledNote(note),
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Lección y captura de movimientos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // 1. Cámara (solo si _showCamera o _isRecording)
          if (_showCamera || _isRecording)
            Positioned.fill(child: CameraView(onShake: _onShakeDetected)),

          // 2. Filtro oscuro semi-transparente
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          // 3. UI de Controles Superpuestos
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título del ejercicio
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Ej: Práctica de Joropo Básico',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        labelText: 'Título de la Lección',
                        labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFFD700)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFFFD700),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selector de Módulos
                    if (_modules.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedModuleId,
                        dropdownColor: Colors.black87,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Asignar a Módulo',
                          labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFFFD700)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFFFD700),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.6),
                        ),
                        items: _modules.map((m) {
                          return DropdownMenuItem<String>(
                            value: m['id'] as String,
                            child: Text(m['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedModuleId = val;
                          });
                        },
                      )
                    else
                      const Text(
                        'No hay módulos creados. Crea uno en el inicio.',
                        style: TextStyle(color: Colors.redAccent),
                      ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<int>(
                      value: _tempoBpm,
                      dropdownColor: Colors.black87,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tempo del metrónomo (BPM)',
                        labelStyle: TextStyle(color: Color(0xFFFFD700)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFFD700)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFFFD700),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Color(0x99000000),
                      ),
                      items: _tempoOptions
                          .map(
                            (bpm) => DropdownMenuItem(
                              value: bpm,
                              child: Text('$bpm BPM'),
                            ),
                          )
                          .toList(),
                      onChanged: _isRecording
                          ? null
                          : (bpm) {
                              if (bpm != null) _changeTempo(bpm);
                            },
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Compás 4/4 · al cambiar el tempo, los movimientos conservan su posición en los pulsos.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildNoteComposer(),
                              if (_recordedNotes.isNotEmpty && !_isRecording)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _confirmClearNotes,
                                    icon: const Icon(Icons.delete_sweep_outlined),
                                    label: const Text('Borrar todas las notas'),
                                  ),
                                ),
                              const SizedBox(height: 12),
                    LessonStaff(notes: _recordedNotes, bpm: _tempoBpm),
                    if (_recordedNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildScheduledNotesList(),
                    ],
                    const SizedBox(height: 12),

                    // Indicador de estado central
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _statusColor, width: 2),
                      ),
                      child: Text(
                        _lastActionText,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Botonera Inferior
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botón Cámara
                        FloatingActionButton(
                          heroTag: 'camera_toggle_btn',
                          backgroundColor: _showCamera ? Colors.blueAccent : Colors.white24,
                          onPressed: () => setState(() => _showCamera = !_showCamera),
                          child: Icon(
                            _showCamera ? Icons.videocam : Icons.videocam_off,
                            color: Colors.white,
                          ),
                        ),

                        // Botón Grabar / Detener
                        FloatingActionButton.large(
                          heroTag: 'record_btn',
                          backgroundColor: _isRecording
                              ? Colors.white
                              : Colors.red,
                          onPressed: _isPreparingRecording
                              ? null
                              : _toggleRecording,
                          child: Icon(
                            _isPreparingRecording
                                ? Icons.hourglass_empty
                                : _isRecording
                                ? Icons.stop
                                : Icons.fiber_manual_record,
                            color: _isRecording ? Colors.red : Colors.white,
                            size: 40,
                          ),
                        ),

                        // Botón Guardar
                        if (!_isRecording && _recordedNotes.isNotEmpty)
                          FloatingActionButton.extended(
                            heroTag: 'save_btn',
                            backgroundColor: const Color(0xFFFFD700),
                            onPressed: _isSaving || _isPreparingRecording
                                ? null
                                : _saveExercise,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.save, color: Colors.black),
                            label: const Text(
                              'Guardar\nLección',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
