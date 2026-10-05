import '../config/database.dart';
import 'package:postgres/postgres.dart';

class NotaRitmo {
  int ms;
  String mano;
  String color;
  String? texto;

  NotaRitmo({
    required this.ms,
    required this.mano,
    required this.color,
    this.texto,
  });

  factory NotaRitmo.fromJson(Map<String, dynamic> json) {
    final rawMs = json['ms'] ?? json['time_ms'] ?? json['timeMs'];
    final ms = rawMs is num
        ? rawMs.toInt()
        : int.tryParse(rawMs?.toString() ?? '');
    if (ms == null) {
      throw const FormatException('La nota no contiene un tiempo válido.');
    }

    final rawHand =
        (json['mano'] ?? json['hand'] ?? json['color'] ?? 'derecha')
            .toString();
    final hand = switch (rawHand.toLowerCase()) {
      'izquierda' || 'left' || 'i' || 'azul' || 'blue' => 'izquierda',
      'derecha' || 'right' || 'd' || 'rojo' || 'red' => 'derecha',
      _ => throw FormatException('Mano no reconocida: $rawHand'),
    };
    final rawColor = json['color']?.toString();
    final rawDirection =
        json['texto'] ?? json['direction'] ?? json['direccion'];

    return NotaRitmo(
      ms: ms,
      mano: hand,
      color:
          rawColor ??
          (hand == 'derecha' ? 'rojo' : 'azul'),
      texto: rawDirection?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ms': ms,
    'mano': mano,
    'color': color,
    'texto': texto,
  };
}

class EjercicioRitmo {
  String id;
  String titulo;
  String descripcion;
  String nivel;
  int tempoBpm;
  List<NotaRitmo> secuenciaNotas;
  String? videoUrl;
  String? pasoAPaso;

  EjercicioRitmo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.nivel,
    required this.tempoBpm,
    required this.secuenciaNotas,
    this.videoUrl,
    this.pasoAPaso,
  });
}

class RitmoModel {
  Future<List<EjercicioRitmo>> listarEjercicios() async {
    final result = await Database.connection.execute(
      Sql.named('''
        SELECT id, titulo, descripcion, nivel, tempo_bpm, secuencia_notas, video_url, paso_a_paso
        FROM ejercicios_ritmo
        ORDER BY fecha_creacion ASC
      '''),
    );

    return result.map((row) {
      final notasList =
          (row[5] as List<dynamic>?)
              ?.map(
                (e) => NotaRitmo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      return EjercicioRitmo(
        id: row[0].toString(),
        titulo: row[1].toString(),
        descripcion: row[2].toString(),
        nivel: row[3].toString(),
        tempoBpm: (row[4] as num).toInt(),
        secuenciaNotas: notasList,
        videoUrl: row[6]?.toString(),
        pasoAPaso: row[7]?.toString(),
      );
    }).toList();
  }

  Future<EjercicioRitmo?> obtenerPorId(String id) async {
    final result = await Database.connection.execute(
      Sql.named('''
        SELECT id, titulo, descripcion, nivel, tempo_bpm, secuencia_notas, video_url, paso_a_paso
        FROM ejercicios_ritmo
        WHERE id = @id
      '''),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    final notasList =
        (row[5] as List<dynamic>?)
            ?.map(
              (e) => NotaRitmo.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];
    return EjercicioRitmo(
      id: row[0].toString(),
      titulo: row[1].toString(),
      descripcion: row[2].toString(),
      nivel: row[3].toString(),
      tempoBpm: (row[4] as num).toInt(),
      secuenciaNotas: notasList,
      videoUrl: row[6]?.toString(),
      pasoAPaso: row[7]?.toString(),
    );
  }
}
