import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class InstructionScreen extends StatefulWidget {
  final String exerciseId;
  const InstructionScreen({super.key, required this.exerciseId});

  @override
  State<InstructionScreen> createState() => _InstructionScreenState();
}

class _InstructionScreenState extends State<InstructionScreen> {
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.pan_tool_outlined,
      'title': 'La Sujeción',
      'desc': 'Sujeta las maracas de forma natural. Mantén las muñecas sueltas para lograr un movimiento fluido al agitar.',
    },
    {
      'icon': Icons.music_note_outlined,
      'title': 'Lectura de Notas',
      'desc': 'Las notas caerán desde la parte superior. Las rojas son para tu mano derecha y las azules para tu mano izquierda.',
    },
    {
      'icon': Icons.camera_front_outlined,
      'title': 'Frente a la Cámara',
      'desc': 'Asegúrate de que la cámara te vea claramente. Cuando la nota llegue abajo, ¡agita la maraca correspondiente!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.xoroBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(3, 3))]),
            children: [
              TextSpan(text: 'XORO', style: TextStyle(color: AppColors.electricBlue)),
              TextSpan(text: 'PO', style: TextStyle(color: AppColors.xoroWhite)),
              TextSpan(text: 'WER', style: TextStyle(color: AppColors.brightRed)),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.xoroWhite),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _pages.length,
              backgroundColor: AppColors.xoroWhite.withOpacity(0.1),
              color: AppColors.electricBlue,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          Expanded(
            child: PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.electricBlue.withOpacity(0.1),
                          border: Border.all(color: AppColors.electricBlue.withOpacity(0.3), width: 2),
                        ),
                        child: Icon(
                          page['icon'] as IconData,
                          size: 80,
                          color: AppColors.electricBlue,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'PASO \${index + 1}',
                        style: const TextStyle(color: AppColors.electricBlue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        page['title'] as String,
                        style: const TextStyle(color: AppColors.xoroWhite, fontSize: 28, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page['desc'] as String,
                        style: TextStyle(color: AppColors.xoroWhite.withOpacity(0.6), fontSize: 16, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  if (isLastPage) {
                    context.pushReplacement('/pantalla_ritmo?exerciseId=${widget.exerciseId}');
                  } else {
                    setState(() {
                      _currentPage++;
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastPage ? 'INICIAR EJERCICIO' : 'SIGUIENTE',
                      style: const TextStyle(color: AppColors.xoroBlack, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (!isLastPage) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: AppColors.xoroBlack, size: 18),
                    ]
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
