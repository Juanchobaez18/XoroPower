import '../config/database.dart';
import 'package:postgres/postgres.dart';
import 'racha_model.dart';

class ProgresoData {
  String? idProgreso;
  String idUsuario;
  String? idEjercicio;
  String? idLeccion;
  String? idModulo;
  bool completado;
  int? puntuacionMasAlta;
  int porcentajeAvance;
  int vecesIntentado;
  DateTime? timestampUltimoIntento;
  DateTime? timestampCompletado;

  ProgresoData({
    this.idProgreso,
    required this.idUsuario,
    this.idEjercicio,
    this.idLeccion,
    this.idModulo,
    required this.completado,
    this.puntuacionMasAlta,
    required this.porcentajeAvance,
    required this.vecesIntentado,
    this.timestampUltimoIntento,
    this.timestampCompletado,
  });
}

class ProgresoResumen {
  final int completadas;
  final int enProgreso;
  final int total;

  ProgresoResumen(this.completadas, this.enProgreso, this.total);
}

class ProgresoModel {
  Future<List<ProgresoData>> listarProgreso(String idUsuario) async {
    final result = await Database.connection.execute(
      Sql.named('''
        SELECT *
        FROM progreso_usuario
        WHERE id_usuario = @idUsuario
        ORDER BY timestamp_ultimo_intento DESC NULLS LAST
      '''),
      parameters: {'idUsuario': idUsuario},
    );

    return result.map((row) {
      return ProgresoData(
        idProgreso: row[0]?.toString(),
        idUsuario: row[1].toString(),
        idEjercicio: row[2]?.toString(),
        idLeccion: row[3]?.toString(),
        idModulo: row[4]?.toString(),
        completado: row[5] as bool,
        puntuacionMasAlta: row[6] as int?,
        porcentajeAvance: row[7] as int,
        vecesIntentado: row[8] as int,
        timestampUltimoIntento: row[9] as DateTime?,
        timestampCompletado: row[10] as DateTime?,
      );
    }).toList();
  }

  Future<ProgresoResumen> obtenerResumen(String idUsuario) async {
    final data = await listarProgreso(idUsuario);
    final completadas = data.where((p) => p.completado).length;
    final enProgreso = data.where((p) => !p.completado).length;
    return ProgresoResumen(completadas, enProgreso, data.length);
  }

  Future<Map<String, dynamic>> actualizarProgreso(
    String idUsuario,
    String idEjercicio,
    int puntuacion,
  ) async {
    try {
      final completado = puntuacion >= 70;

      await Database.connection.execute(
        Sql.named('''
          INSERT INTO progreso_usuario
            (id_usuario, id_ejercicio, completado, puntuacion_mas_alta, porcentaje_avance, veces_intentado, timestamp_ultimo_intento)
          VALUES
            (@idUsuario, @idEjercicio, @completado, @puntuacion, @puntuacion, 1, NOW())
          ON CONFLICT (id_usuario, id_ejercicio)
          DO UPDATE SET
            completado            = GREATEST(progreso_usuario.completado, EXCLUDED.completado),
            puntuacion_mas_alta   = GREATEST(progreso_usuario.puntuacion_mas_alta, EXCLUDED.puntuacion_mas_alta),
            porcentaje_avance     = GREATEST(progreso_usuario.porcentaje_avance, EXCLUDED.porcentaje_avance),
            veces_intentado       = progreso_usuario.veces_intentado + 1,
            timestamp_ultimo_intento = NOW(),
            timestamp_completado  = CASE
              WHEN EXCLUDED.completado = true AND progreso_usuario.timestamp_completado IS NULL
              THEN NOW()
              ELSE progreso_usuario.timestamp_completado
            END
          RETURNING *
        '''),
        parameters: {
          'idUsuario': idUsuario,
          'idEjercicio': idEjercicio,
          'completado': completado,
          'puntuacion': puntuacion,
        },
      );

      try {
        await RachaModel.registrarActividad(idUsuario);
      } catch (e) {
        print("Error al actualizar racha: \$e");
      }

      return {
        'success': true,
        'message': completado ? "¡Ejercicio completado!" : "Progreso guardado.",
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
