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
    if (mounted) {
      setState(() {
        _exercises = allExercises.where((exercise) {
          final moduleId = exercise['modulo_id'] ?? exercise['module_id'];
          return moduleId?.toString() == widget.moduleId;
        }).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExercise(Map<String, dynamic> exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lección'),
        content: Text(
          '¿Eliminar "${exercise['titulo'] ?? 'Lección'}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteExercise(exercise['id'].toString());
      await _loadExercises();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lección eliminada.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }

  Future<void> _editExercise(Map<String, dynamic> exercise) async {
    await context.push(
      '/admin_add_exercise?exerciseId=${exercise['id']}&moduleId=${widget.moduleId}',
    );
    if (mounted) _loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(apiClientProvider).isAdmin;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Lecciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Crear lección',
              icon: const Icon(Icons.add),
              onPressed: () {
                context
                    .push('/admin_add_exercise?moduleId=${widget.moduleId}')
                    .then((_) {
                      if (mounted) _loadExercises();
                    });
              },
            ),
        ],
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
                    'Aún no hay lecciones en este módulo.',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        context
                            .push(
                              '/admin_add_exercise?moduleId=${widget.moduleId}',
                            )
                            .then((_) {
                              if (mounted) _loadExercises();
                            });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Crear lección'),
                    ),
                  ],
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
                      if (!isAdmin)
                        context.push('/instructions/${exercise["id"]}');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0055FF).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFF0055FF).withOpacity(0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF0055FF),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise['titulo'] ?? 'Lección ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Duración estimada: 2 min',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            PopupMenuButton<String>(
                              tooltip: 'Gestionar lección',
                              onSelected: (action) {
                                if (action == 'edit') _editExercise(exercise);
                                if (action == 'delete')
                                  _deleteExercise(exercise);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar y regrabar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            )
                          else
                            Icon(
                              Icons.chevron_right,
                              color: const Color(0xFF0055FF).withOpacity(0.6),
                              size: 22,
                            ),
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
