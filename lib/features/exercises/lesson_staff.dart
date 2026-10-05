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

  static int quantizeTimeMs(int timeMs, int bpm) {
    if (bpm <= 0) {
      throw ArgumentError.value(bpm, 'bpm', 'Debe ser mayor que cero.');
    }
    if (timeMs < 0) {
      throw ArgumentError.value(timeMs, 'timeMs', 'No puede ser negativo.');
    }
    final beatDurationMs = 60000 / bpm;
    return ((timeMs / beatDurationMs).round() * beatDurationMs).round();
  }

  factory StaffNote.fromJson(Map<String, dynamic> json) {
    final rawTime = json['time_ms'] ?? json['ms'] ?? json['timeMs'];
    final timeMs = rawTime is num
        ? rawTime.toInt()
        : int.tryParse(rawTime?.toString() ?? '');
    if (timeMs == null) {
      throw const FormatException('La nota no contiene un tiempo válido.');
    }

    final rawHand =
        (json['hand'] ?? json['mano'] ?? json['color'] ?? 'derecha')
            .toString()
            .toLowerCase();
    final hand = switch (rawHand) {
      'izquierda' || 'left' || 'i' || 'azul' || 'blue' => 'izquierda',
      'derecha' || 'right' || 'd' || 'rojo' || 'red' => 'derecha',
      _ => throw FormatException('Mano no reconocida: $rawHand'),
    };

    final explicitDirection = json['direction'] ?? json['direccion'];
    final rawDirection = (explicitDirection ?? json['texto'] ?? 'abajo')
        .toString()
        .toLowerCase();
    final direction = switch (rawDirection) {
      'arriba' || 'up' || '↑' => 'arriba',
      'abajo' || 'down' || '↓' => 'abajo',
      _ when explicitDirection == null => 'abajo',
      _ => throw FormatException('Dirección no reconocida: $rawDirection'),
    };

    return StaffNote(timeMs: timeMs, hand: hand, direction: direction);
  }

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
    final safeBpm = bpm > 0 ? bpm : 120;
    final beatMs = 60000 / safeBpm;
    final maxTimeMs = notes.fold<int>(
      0,
      (max, note) => max > note.timeMs ? max : note.timeMs,
    );
    final rawBeatCount = math.max(8, (maxTimeMs / beatMs).ceil() + 1);
    final int beatCount = ((rawBeatCount + 3) ~/ 4) * 4;
    final double boardWidth = math.max(1200.0, 168 + beatCount * 110.0);

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
            bpm: safeBpm,
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
    canvas.drawColor(const Color(0xFF101113), BlendMode.src);
    final ink = const Color(0xFFF1E6D2);
    final red = const Color(0xFFE53935);
    final blue = const Color(0xFF1E88E5);
    final linePaint = Paint()..strokeWidth = 1.5;
    const staffLineStartX = 22.0;
    const staffStartX = 140.0;
    const staffEndInset = 24.0;
    for (var line = 0; line < 5; line++) {
      final y = 48.0 + line * 14;
      linePaint.color = line == 2 ? red.withOpacity(.82) : ink.withOpacity(.35);
      linePaint.strokeWidth = line == 2 ? 3 : 1.5;
      canvas.drawLine(
        Offset(staffLineStartX, y),
        Offset(size.width - staffEndInset, y),
        linePaint,
      );

      final blueY = y + 100;
      linePaint.color = line == 2
          ? blue.withOpacity(.82)
          : ink.withOpacity(.35);
      linePaint.strokeWidth = line == 2 ? 3 : 1.5;
      canvas.drawLine(
        Offset(staffLineStartX, blueY),
        Offset(size.width - staffEndInset, blueY),
        linePaint,
      );
    }

    _drawText(canvas, 'PERCUSIÓN', const Offset(22, 15), 10, ink);
    _drawPercussionClef(canvas, const Offset(35, 77), ink);
    _drawPercussionClef(canvas, const Offset(35, 177), ink);
    _drawText(canvas, '4', const Offset(68, 58), 30, ink);
    _drawText(canvas, '4', const Offset(68, 88), 30, ink);
    canvas.drawLine(
      const Offset(65, 85),
      const Offset(91, 85),
      Paint()
        ..color = ink
        ..strokeWidth = 2.5,
    );
    _drawText(canvas, 'D', const Offset(108, 65), 22, red);
    _drawText(canvas, 'I', const Offset(108, 165), 22, blue);

    final step =
        (size.width - staffStartX - staffEndInset) / math.max(beatCount, 1);
    final startX = staffStartX;
    final endX = startX + beatCount * step;
    final beatMs = 60000 / bpm;
    final barPaint = Paint()
      ..color = ink
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(startX, 48, 7, 170), Paint()..color = ink);
    canvas.drawRect(
      Rect.fromLTWH(startX + 11, 48, 2.5, 170),
      Paint()..color = ink,
    );
    _drawRepeatDots(canvas, startX + 22, ink);

    for (var beat = 0; beat < beatCount; beat++) {
      final x = startX + (beat + .5) * step;
      if (beat > 0 && beat % 4 == 0) {
        canvas.drawLine(
          Offset(startX + beat * step, 48),
          Offset(startX + beat * step, 218),
          barPaint,
        );
      }
      _drawText(
        canvas,
        '${beat % 4 + 1}',
        Offset(x - 5, 121),
        12,
        ink.withOpacity(.68),
      );
    }
    canvas.drawLine(
      Offset(endX - 13, 48),
      Offset(endX - 13, 218),
      Paint()
        ..color = ink
        ..strokeWidth = 2.5,
    );
    canvas.drawRect(Rect.fromLTWH(endX - 7, 48, 9, 170), Paint()..color = ink);
    _drawRepeatDots(canvas, endX - 31, ink);

    final occupiedBeats = <String>{};
    for (final note in notes) {
      final beat = (note.timeMs / beatMs).round().clamp(0, beatCount - 1);
      occupiedBeats.add('$beat:${note.hand}');
    }
    for (var beat = 0; beat < beatCount; beat++) {
      final x = startX + (beat + .5) * step;
      if (!occupiedBeats.contains('$beat:derecha')) {
        _drawQuarterRest(canvas, Offset(x, 76), ink.withOpacity(.72));
      }
      if (!occupiedBeats.contains('$beat:izquierda')) {
        _drawQuarterRest(canvas, Offset(x, 176), ink.withOpacity(.72));
      }
    }

    for (final note in notes) {
      final beat = (note.timeMs / beatMs).round().clamp(0, beatCount - 1);
      final x = startX + (beat + .5) * step;
      final isRight = note.hand == 'derecha';
      final y = isRight ? 76.0 : 176.0;
      final color = note.hit
          ? const Color(0xFF55C86A)
          : note.missed
          ? const Color(0xFF777777)
          : isRight
          ? red
          : blue;
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
        Offset(x + 13, y - 13),
        16,
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
      final cursorX = startX + ((currentMs / beatMs) + .5) * step;
      canvas.drawLine(
        Offset(cursorX, 42),
        Offset(cursorX, 220),
        Paint()
          ..color = const Color(0xFFD4AF37).withOpacity(.28)
          ..strokeWidth = 10,
      );
      canvas.drawLine(
        Offset(cursorX, 42),
        Offset(cursorX, 220),
        Paint()
          ..color = const Color(0xFF9C7411)
          ..strokeWidth = 2,
      );
    }
  }

  void _drawPercussionClef(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5;
    canvas.drawLine(
      Offset(center.dx - 4, center.dy - 27),
      Offset(center.dx - 4, center.dy + 27),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 5, center.dy - 27),
      Offset(center.dx + 5, center.dy + 27),
      paint,
    );
    canvas.drawCircle(Offset(center.dx + 14, center.dy - 16), 3, paint);
    canvas.drawCircle(Offset(center.dx + 14, center.dy + 16), 3, paint);
  }

  void _drawRepeatDots(Canvas canvas, double x, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(x, 70), 3, paint);
    canvas.drawCircle(Offset(x, 86), 3, paint);
    canvas.drawCircle(Offset(x, 170), 3, paint);
    canvas.drawCircle(Offset(x, 186), 3, paint);
  }

  void _drawQuarterRest(Canvas canvas, Offset center, Color color) {
    final path = Path()
      ..moveTo(center.dx + 3, center.dy - 16)
      ..lineTo(center.dx - 4, center.dy - 7)
      ..lineTo(center.dx + 4, center.dy - 1)
      ..lineTo(center.dx - 3, center.dy + 8)
      ..quadraticBezierTo(
        center.dx - 7,
        center.dy + 14,
        center.dx - 1,
        center.dy + 15,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(center.dx - 1, center.dy + 15),
      2,
      Paint()..color = color,
    );
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
