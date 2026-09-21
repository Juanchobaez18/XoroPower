import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class ModuleDetailScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  ConsumerState<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends ConsumerState<ModuleDetailScreen> {
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final api = ref.read(apiClientProvider);
    final allExercises = await api.getExercises();
    
    // Filtramos los ejercicios por módulo (si tuvieran moduleId guardado, por ahora mostramos todos como prueba)
    // Asumiendo que `getExercises` devuelve todos.
    if (mounted) {
      setState(() {
        _exercises = allExercises; // Si implementáramos filtrado: allExercises.where((e) => e['moduleId'] == widget.moduleId).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ejercicios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🪘', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no hay ejercicios en este módulo.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          // Navegar al InstructionScreen con el ID del ejercicio
                          context.push('/instructions/\${exercise["id"]}');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0055FF).withOpacity(0.1),
                                  border: Border.all(color: const Color(0xFF0055FF).withOpacity(0.3)),
                                ),
                                alignment: Alignment.center,
                                child: Text('\${index + 1}', style: const TextStyle(color: Color(0xFF0055FF), fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise['titulo'] ?? 'Ejercicio \${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Duración estimada: 2 min',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: const Color(0xFF0055FF).withOpacity(0.6), size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
