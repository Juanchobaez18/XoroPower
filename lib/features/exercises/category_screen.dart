import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String _selectedLevel = 'basico';
  List<Map<String, dynamic>> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    final api = ref.read(apiClientProvider);
    final modules = await api.getModules();
    if (mounted) {
      setState(() {
        _modules = modules;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final esAdmin = api.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENTRENAMIENTO',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'CATEGORÍAS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Admin Mode Banner
          if (esAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35)),
                ),
                child: const Text(
                  'Modo administrador: todos los niveles y ejercicios están desbloqueados.',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (esAdmin) const SizedBox(height: 12),

          // Level Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _LevelTab(
                  label: 'Básico',
                  isSelected: _selectedLevel == 'basico',
                  color: const Color(0xFF0055FF),
                  onTap: () => setState(() => _selectedLevel = 'basico'),
                ),
                const SizedBox(width: 10),
                _LevelTab(
                  label: 'Intermedio',
                  isSelected: _selectedLevel == 'intermedio',
                  color: const Color(0xFFFFD700),
                  onTap: () => setState(() => _selectedLevel = 'intermedio'),
                ),
                const SizedBox(width: 10),
                _LevelTab(
                  label: 'Avanzado',
                  isSelected: _selectedLevel == 'avanzado',
                  color: const Color(0xFFF44336),
                  onTap: () => setState(() => _selectedLevel = 'avanzado'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Exercises List
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_modules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('No hay categorías disponibles.', style: TextStyle(color: Colors.white54)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _modules.length,
              itemBuilder: (context, index) {
                final module = _modules[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                  child: _CategoryActivityCard(
                    id: (index + 1).toString(),
                    title: module['name'] as String,
                    desc: module['description'] as String,
                    isUnlocked: true,
                    onClick: () {
                      context.push('/module/\${module["id"]}');
                    },
                  ),
                );
              },
            ),
            
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _LevelTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _LevelTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04);
    final borderColor = isSelected ? color.withOpacity(0.7) : Colors.white.withOpacity(0.1);
    final textColor = isSelected ? color : Colors.white.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CategoryActivityCard extends StatelessWidget {
  final String id;
  final String title;
  final String desc;
  final bool isUnlocked;
  final VoidCallback onClick;

  const _CategoryActivityCard({
    required this.id,
    required this.title,
    required this.desc,
    required this.isUnlocked,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = isUnlocked ? 1.0 : 0.5;

    return GestureDetector(
      onTap: isUnlocked ? onClick : null,
      child: Opacity(
        opacity: alpha,
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
                  color: isUnlocked ? const Color(0xFF0055FF).withOpacity(0.1) : Colors.transparent,
                  border: Border.all(
                    color: isUnlocked ? const Color(0xFF0055FF).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                  ),
                ),
                alignment: Alignment.center,
                child: isUnlocked
                    ? Text(id, style: const TextStyle(color: Color(0xFF0055FF), fontWeight: FontWeight.w900))
                    : Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.3), size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (isUnlocked)
                Icon(Icons.chevron_right, color: const Color(0xFF0055FF).withOpacity(0.6), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
