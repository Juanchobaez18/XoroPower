import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/audio_service.dart';
import '../../core/vision/pose_detector_service.dart';
import 'camera_view.dart';

class AdminAddExerciseScreen extends ConsumerStatefulWidget {
  const AdminAddExerciseScreen({super.key});

  @override
  ConsumerState<AdminAddExerciseScreen> createState() => _AdminAddExerciseScreenState();
}

class _AdminAddExerciseScreenState extends ConsumerState<AdminAddExerciseScreen> {
  final TextEditingController _titleController = TextEditingController();
  
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _metronomeTimer;
  
  final List<Map<String, dynamic>> _recordedNotes = [];
  
  String _lastActionText = "Listo para grabar";
  Color _statusColor = Colors.white;

  List<Map<String, dynamic>> _modules = [];
  String? _selectedModuleId;

  @override
  void initState() {
    super.initState();
    _loadModules();
    ref.read(audioServiceProvider).init();
  }

  Future<void> _loadModules() async {
    final api = ref.read(apiClientProvider);
    final modules = await api.getModules();
    if (mounted) {
      setState(() {
        _modules = modules;
        if (_modules.isNotEmpty) {
          _selectedModuleId = _modules.first['id'] as String;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _metronomeTimer?.cancel();
    super.dispose();
  }

  void _onShakeDetected(HandSide side) {
    if (!_isRecording || _recordingStartTime == null) return;
    
    final elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    
    setState(() {
      _recordedNotes.add({
        'time_ms': elapsedMs,
        'hand': side == HandSide.right ? 'derecha' : 'izquierda',
      });
      
      _lastActionText = side == HandSide.right ? "GOLPE DERECHO" : "GOLPE IZQUIERDO";
      _statusColor = side == HandSide.right ? const Color(0xFFFF0033) : const Color(0xFF0055FF);
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

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        // Detener grabación
        _isRecording = false;
        _metronomeTimer?.cancel();
        _lastActionText = "Grabación detenida. ${_recordedNotes.length} notas capturadas.";
        _statusColor = Colors.white;
      } else {
        // Iniciar grabación
        _recordedNotes.clear();
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _lastActionText = "Grabando... ¡Mueve tus manos!";
        _statusColor = Colors.greenAccent;
        
        // Iniciar metrónomo (120 BPM = 500ms)
        _metronomeTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          ref.read(audioServiceProvider).playMetronome();
        });
      }
    });
  }

  Future<void> _saveExercise() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un título para la lección')),
      );
      return;
    }
    
    if (_selectedModuleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona o crea un módulo primero')),
      );
      return;
    }
    
    if (_recordedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No has grabado ninguna nota aún')),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    
    try {
      await api.saveExercise({
        'titulo': _titleController.text.trim(),
        'modulo_id': _selectedModuleId,
        'notas': _recordedNotes, // Supabase SDK handlea List<Map> y lo guarda como JSONB
        'creado_el': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Lección guardada exitosamente!')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: \$e')),
        );
      }
    }
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
          'Crear Lección (Motion Capture)',
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
          // 1. Cámara en el fondo para ver nuestro propio cuerpo al grabar
          Positioned.fill(
            child: CameraView(onShake: _onShakeDetected),
          ),
          
          // 2. Filtro oscuro semi-transparente
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          // 3. UI de Controles Superpuestos
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Título del ejercicio
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Ej: Práctica de Joropo Básico',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      labelText: 'Título de la Lección',
                      labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFFD700)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Asignar a Módulo',
                        labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFFD700)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
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
                    const Text('No hay módulos creados. Crea uno en el inicio.', style: TextStyle(color: Colors.redAccent)),
                  
                  const Spacer(),
                  
                  // Indicador de estado central
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),

                  const Spacer(),
                  
                  // Botonera Inferior
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón Grabar / Detener
                      FloatingActionButton.large(
                        heroTag: 'record_btn',
                        backgroundColor: _isRecording ? Colors.white : Colors.red,
                        onPressed: _toggleRecording,
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.fiber_manual_record,
                          color: _isRecording ? Colors.red : Colors.white,
                          size: 40,
                        ),
                      ),
                      
                      // Botón Guardar
                      if (!_isRecording && _recordedNotes.isNotEmpty)
                        FloatingActionButton.extended(
                          heroTag: 'save_btn',
                          backgroundColor: const Color(0xFFFFD700),
                          onPressed: _saveExercise,
                          icon: const Icon(Icons.save, color: Colors.black),
                          label: const Text(
                            'Guardar\nLección',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
