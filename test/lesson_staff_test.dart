import 'package:flutter_test/flutter_test.dart';
import 'package:xoropower/features/exercises/lesson_staff.dart';

void main() {
  group('StaffNote', () {
    test('quantizes event timestamps to the nearest beat', () {
      expect(StaffNote.quantizeTimeMs(240, 120), 0);
      expect(StaffNote.quantizeTimeMs(270, 120), 500);
      expect(StaffNote.quantizeTimeMs(1120, 120), 1000);
    });

    test('reads both exercise JSON formats', () {
      final currentFormat = StaffNote.fromJson({
        'time_ms': 500,
        'hand': 'izquierda',
        'direction': 'arriba',
      });
      final legacyFormat = StaffNote.fromJson({
        'ms': 1000,
        'mano': 'right',
        'color': 'rojo',
        'texto': 'down',
      });

      expect(currentFormat.timeMs, 500);
      expect(currentFormat.hand, 'izquierda');
      expect(currentFormat.direction, 'arriba');
      expect(legacyFormat.timeMs, 1000);
      expect(legacyFormat.hand, 'derecha');
      expect(legacyFormat.direction, 'abajo');

      final legacyDescription = StaffNote.fromJson({
        'ms': 1500,
        'mano': 'izquierda',
        'texto': 'golpe de percusión',
      });
      expect(legacyDescription.direction, 'abajo');
    });
  });
}
