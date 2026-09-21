import '../config/database.dart';
import 'package:postgres/postgres.dart';

class ModuloData {
  String idModulo;
  String identificador;
  String titulo;
  String? descripcion;
  int orden;

  ModuloData({
    required this.idModulo,
    required this.identificador,
    required this.titulo,
    this.descripcion,
    required this.orden,
  });
}

class SeccionData {
  String idSeccion;
  String moduloId;
  String nivel;
  String titulo;
  String? descripcion;
  int orden;
  List<ActividadData>? actividades;

  SeccionData({
    required this.idSeccion,
    required this.moduloId,
    required this.nivel,
    required this.titulo,
    this.descripcion,
    required this.orden,
    this.actividades,
  });
}

class ActividadData {
  String idActividad;
  String seccionId;
  String tipo;
  String titulo;
  String? textoCuerpo;
  String? urlVideo;
  int orden;

  ActividadData({
    required this.idActividad,
    required this.seccionId,
    required this.tipo,
    required this.titulo,
    this.textoCuerpo,
    this.urlVideo,
    required this.orden,
  });
}

class ModuloModel {
  static List<ModuloData>? _cacheModulos;
  static int _ultimaActualizacion = 0;
  static const int refrescoMs = 5 * 60 * 1000;

  Future<void> sincronizarCache() async {
    final result = await Database.connection.execute(
      Sql.named('''
        SELECT id_modulo, identificador, titulo, descripcion, orden
        FROM modulos
        ORDER BY orden ASC
      '''),
    );
    _cacheModulos = result.map((row) {
      return ModuloData(
        idModulo: row[0].toString(),
        identificador: row[1].toString(),
        titulo: row[2].toString(),
        descripcion: row[3]?.toString(),
        orden: row[4] as int,
      );
    }).toList();
    _ultimaActualizacion = DateTime.now().millisecondsSinceEpoch;
  }

  Future<List<ModuloData>> listarModulos() async {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (_cacheModulos != null && (ahora - _ultimaActualizacion < refrescoMs)) {
      return _cacheModulos!;
    }
    await sincronizarCache();
    return _cacheModulos ?? [];
  }

  Future<ModuloData?> obtenerPorIdentificador(String id) async {
    final result = await Database.connection.execute(
      Sql.named('SELECT id_modulo, identificador, titulo, descripcion, orden FROM modulos WHERE id_modulo = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return ModuloData(
      idModulo: row[0].toString(),
      identificador: row[1].toString(),
      titulo: row[2].toString(),
      descripcion: row[3]?.toString(),
      orden: row[4] as int,
    );
  }

  Future<SeccionData?> obtenerSeccionPorNivel(String moduloId, String nivel) async {
    final seccionResult = await Database.connection.execute(
      Sql.named('''
        SELECT id_seccion, modulo_id, nivel, titulo, descripcion, orden
        FROM secciones
        WHERE modulo_id = @moduloId AND nivel = @nivel
      '''),
      parameters: {'moduloId': moduloId, 'nivel': nivel},
    );

    if (seccionResult.isEmpty) return null;
    final secRow = seccionResult.first;
    
    final actResult = await Database.connection.execute(
      Sql.named('''
        SELECT id_actividad, seccion_id, tipo, titulo, texto_cuerpo, url_video, orden
        FROM actividades
        WHERE seccion_id = @idSeccion
        ORDER BY orden ASC
      '''),
      parameters: {'idSeccion': secRow[0].toString()},
    );

    final actividades = actResult.map((row) => ActividadData(
      idActividad: row[0].toString(),
      seccionId: row[1].toString(),
      tipo: row[2].toString(),
      titulo: row[3].toString(),
      textoCuerpo: row[4]?.toString(),
      urlVideo: row[5]?.toString(),
      orden: row[6] as int,
    )).toList();

    return SeccionData(
      idSeccion: secRow[0].toString(),
      moduloId: secRow[1].toString(),
      nivel: secRow[2].toString(),
      titulo: secRow[3].toString(),
      descripcion: secRow[4]?.toString(),
      orden: secRow[5] as int,
      actividades: actividades,
    );
  }
}
