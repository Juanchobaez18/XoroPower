import '../config/database.dart';
import 'package:postgres/postgres.dart';

class RachaData {
  String? id;
  String idUsuario;
  int rachaActual;
  int rachaMaxima;
  DateTime? ultimaFecha;

  RachaData({
    this.id,
    required this.idUsuario,
    required this.rachaActual,
    required this.rachaMaxima,
    this.ultimaFecha,
  });
}

class RachaModel {
  static Future<RachaData> registrarActividad(String idUsuario) async {
    try {
      final result = await Database.connection.execute(
        Sql.named('''
          INSERT INTO rachas_usuario (id_usuario, racha_actual, racha_maxima, ultima_fecha)
          VALUES (@idUsuario, 1, 1, CURRENT_DATE)
          ON CONFLICT (id_usuario)
          DO UPDATE SET
            racha_actual = CASE
              WHEN rachas_usuario.ultima_fecha = CURRENT_DATE THEN rachas_usuario.racha_actual
              WHEN rachas_usuario.ultima_fecha = CURRENT_DATE - INTERVAL '1 day' THEN rachas_usuario.racha_actual + 1
              ELSE 1
            END,
            racha_maxima = CASE
              WHEN rachas_usuario.ultima_fecha = CURRENT_DATE THEN rachas_usuario.racha_maxima
              WHEN rachas_usuario.ultima_fecha = CURRENT_DATE - INTERVAL '1 day' THEN GREATEST(rachas_usuario.racha_maxima, rachas_usuario.racha_actual + 1)
              ELSE GREATEST(rachas_usuario.racha_maxima, 1)
            END,
            ultima_fecha = CURRENT_DATE
          RETURNING racha_actual, racha_maxima, ultima_fecha
        '''),
        parameters: {'idUsuario': idUsuario},
      );
      
      final row = result.first;
      return RachaData(
        idUsuario: idUsuario,
        rachaActual: row[0] as int,
        rachaMaxima: row[1] as int,
        ultimaFecha: row[2] as DateTime?,
      );
    } catch (e) {
      print("Error al registrar actividad (racha): \$e");
      throw Exception("No se pudo registrar la actividad.");
    }
  }

  static Future<RachaData> obtenerRacha(String idUsuario) async {
    try {
      final result = await Database.connection.execute(
        Sql.named('''
          SELECT 
            racha_actual, 
            racha_maxima, 
            ultima_fecha
          FROM rachas_usuario
          WHERE id_usuario = @idUsuario
        '''),
        parameters: {'idUsuario': idUsuario},
      );

      if (result.isEmpty) {
        return RachaData(
          idUsuario: idUsuario,
          rachaActual: 0,
          rachaMaxima: 0,
          ultimaFecha: null,
        );
      }
      
      final row = result.first;
      return RachaData(
        idUsuario: idUsuario,
        rachaActual: row[0] as int,
        rachaMaxima: row[1] as int,
        ultimaFecha: row[2] as DateTime?,
      );
    } catch (e) {
      print("Error al obtener racha: \$e");
      throw Exception("No se pudo obtener la racha del usuario.");
    }
  }
}
