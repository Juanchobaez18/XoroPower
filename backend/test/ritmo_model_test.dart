import 'package:backend/models/ritmo_model.dart';
import 'package:test/test.dart';

void main() {
  group('NotaRitmo.fromJson', () {
    test('reads the legacy backend note format', () {
      final note = NotaRitmo.fromJson({
        'ms': 750,
        'mano': 'izquierda',
        'color': 'azul',
        'texto': 'arriba',
      });

      expect(note.ms, 750);
      expect(note.mano, 'izquierda');
      expect(note.color, 'azul');
      expect(note.texto, 'arriba');
    });

    test('accepts the exercise note format used by the client', () {
      final note = NotaRitmo.fromJson({
        'time_ms': 500,
        'hand': 'right',
        'direction': 'down',
      });

      expect(note.ms, 500);
      expect(note.mano, 'derecha');
      expect(note.color, 'rojo');
      expect(note.texto, 'down');
    });
  });
}
