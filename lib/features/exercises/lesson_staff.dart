import 'dart:math' as math;

import 'package:flutter/material.dart';

class StaffNote {
  final int timeMs;
  final String hand;
  final String direction;
  bool hit;
  bool missed;

  StaffNote({
    required this.timeMs,
    required this.hand,
    this.direction = 'abajo',
    this.hit = false,
    this.missed = false,
  });

  factory StaffNote.fromJson(Map<String, dynamic> json) => StaffNote(
    timeMs: (json['time_ms'] as num).toInt(),
    hand: json['hand'] as String? ?? 'derecha',
    direction: json['direction'] as String? ?? 'abajo',
  );

  Map<String, dynamic> toJson() => {
    'time_ms': timeMs,
    'hand': hand,
    'direction': direction,
  };
}

class LessonStaff extends StatelessWidget {
  final List<StaffNote> notes;
  final int bpm;
  final int currentMs;

  const LessonStaff({
    super.key,
    required this.notes,
    required this.bpm,
    this.currentMs = -1,
  });

  @override
  Widget build(BuildContext context) {
    final beatMs = 60000 / bpm;
    final maxTimeMs = notes.fold<int>(
      0,
      (max, note) => max > note.timeMs ? max : note.timeMs,
    );
    final int beatCount = math.max(8, (maxTimeMs / beatMs).ceil() + 1);
    final double boardWidth = math
        .max(1200.0, 340 + beatCount * 110.0)
        .toDouble();

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF08090B),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CustomPaint(
          size: Size(boardWidth, 246),
          painter: _LessonStaffPainter(
            notes: notes,
            bpm: bpm,
            currentMs: currentMs,
            beatCount: beatCount,
          ),
        ),
      ),
    );
  }
}

class _LessonStaffPainter extends CustomPainter {
  final List<StaffNote> notes;
  final int bpm;
  final int currentMs;
  final int beatCount;

  _LessonStaffPainter({
    required this.notes,
    required this.bpm,
    required this.currentMs,
    required this.beatCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF08090B), BlendMode.src);
    final linePaint = Paint()..strokeWidth = 1.5;
    for (var line = 0; line < 5; line++) {
      final y = 62.0 + line * 16;
      linePaint.color = line == 2
          ? const Color(0xFFE53935)
          : Colors.white.withOpacity(.48);
      linePaint.strokeWidth = line == 2 ? 3 : 1.5;
      canvas.drawLine(Offset(130, y), Offset(size.width - 28, y), linePaint);

      final blueY = y + 100;
      linePaint.color = line == 2
          ? const Color(0xFF1E88E5)
          : Colors.white.withOpacity(.48);
      linePaint.strokeWidth = line == 2 ? 3 : 1.5;
      canvas.drawLine(
        Offset(130, blueY),
        Offset(size.width - 28, blueY),
        linePaint,
      );
    }

    _drawText(canvas, '4', const Offset(35, 72), 40, Colors.white);
    _drawText(canvas, '4', const Offset(35, 120), 40, Colors.white);
    canvas.drawLine(
      const Offset(27, 116),
      const Offset(76, 116),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
    _drawText(canvas, 'D', const Offset(82, 68), 24, Colors.white);
    _drawText(canvas, 'I', const Offset(88, 168), 24, Colors.white);

    final step = (size.width - 190) / math.max(beatCount, 1);
    final beatMs = 60000 / bpm;
    final barPaint = Paint()
      ..color = Colors.white.withOpacity(.7)
      ..strokeWidth = 2;
    for (var beat = 0; beat < beatCount; beat++) {
      final x = 150 + beat * step;
      if (beat % 4 == 0) {
        canvas.drawLine(
          Offset(x - step / 2, 48),
          Offset(x - step / 2, 219),
          barPaint,
        );
      }
      _drawText(
        canvas,
        '${beat % 4 + 1}',
        Offset(x - 6, 132),
        13,
        Colors.white70,
      );
    }
    canvas.drawLine(
      Offset(150 + beatCount * step - step / 2, 48),
      Offset(150 + beatCount * step - step / 2, 219),
      barPaint,
    );

    for (final note in notes) {
      final beat = note.timeMs / beatMs;
      final x = 150 + beat * step;
      final isRight = note.hand == 'derecha';
      final y = isRight ? 62.0 + 32 : 62.0 + 132;
      final color = note.hit
          ? const Color(0xFF55C86A)
          : note.missed
          ? const Color(0xFF777777)
          : isRight
          ? const Color(0xFFE53935)
          : const Color(0xFF1E88E5);
      final headPaint = Paint()..color = color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 13),
        headPaint,
      );
      canvas.restore();
      final stemX = x + (note.direction == 'arriba' ? 8 : -8);
      canvas.drawLine(
        Offset(stemX, y + (note.direction == 'arriba' ? -2 : 2)),
        Offset(stemX, y + (note.direction == 'arriba' ? -31 : 31)),
        Paint()
          ..color = color
          ..strokeWidth = 2.5,
      );
      _drawText(
        canvas,
        note.direction == 'arriba' ? '↑' : '↓',
        Offset(x - 6, y + 17),
        13,
        color,
      );
      if (note.missed) {
        _drawText(
          canvas,
          '×',
          Offset(x - 6, y - 30),
          18,
          const Color(0xFFFF5252),
        );
      }
    }

    if (currentMs >= 0) {
      final cursorX = 150 + (currentMs / beatMs) * step;
      canvas.drawLine(
        Offset(cursorX, 46),
        Offset(cursorX, 222),
        Paint()
          ..color = const Color(0xFFD4AF37)
          ..strokeWidth = 3,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _LessonStaffPainter oldDelegate) => true;
}
