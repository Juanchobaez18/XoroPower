import '../config/database.dart';
import 'package:postgres/postgres.dart';
import 'dart:convert';

class NotaRitmo {
  int ms;
  String mano;
  String color;
  String? texto;

  NotaRitmo({required this.ms, required this.mano, required this.color, this.texto});

  factory NotaRitmo.fromJson(Map<String, dynamic> json) {
    return NotaRitmo(
      ms: json['ms'] as int,
      mano: json['mano'] as String,
      color: json['color'] as String,
      texto: json['texto'] as String?,
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
      final notasList = (row[5] as List<dynamic>?)?.map((e) => NotaRitmo.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      return EjercicioRitmo(
        id: row[0].toString(),
        titulo: row[1].toString(),
        descripcion: row[2].toString(),
        nivel: row[3].toString(),
        tempoBpm: row[4] as int,
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
    final notasList = (row[5] as List<dynamic>?)?.map((e) => NotaRitmo.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return EjercicioRitmo(
      id: row[0].toString(),
      titulo: row[1].toString(),
      descripcion: row[2].toString(),
      nivel: row[3].toString(),
      tempoBpm: row[4] as int,
      secuenciaNotas: notasList,
      videoUrl: row[6]?.toString(),
      pasoAPaso: row[7]?.toString(),
    );
  }
}
