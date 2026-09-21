import '../config/database.dart';
import 'package:crypt/crypt.dart';
import 'package:postgres/postgres.dart';

class UsuarioData {
  String? idUsuario;
  String email;
  String nombreUsuario;
  String? passwordHash;
  String? avatar;
  String? rol;

  UsuarioData({
    this.idUsuario,
    required this.email,
    required this.nombreUsuario,
    this.passwordHash,
    this.avatar,
    this.rol,
  });
}

class UsuarioModel {
  UsuarioData? objUsuario;

  UsuarioModel([this.objUsuario]);

  Future<UsuarioData?> buscarPorEmail() async {
    if (objUsuario?.email == null) throw Exception("Email no proporcionado.");
    
    final result = await Database.connection.execute(
      Sql.named('''
        SELECT 
          u.id_usuario,
          u.email, 
          u.nombre_usuario,
          u.password_hash,
          u.rol,
          COALESCE(a.url_imagen, '🤠') as avatar
        FROM usuarios u
        LEFT JOIN avatares a ON u.nombre_usuario = a.nombre
        WHERE u.email = @email
        LIMIT 1
      '''),
      parameters: {'email': objUsuario!.email},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return UsuarioData(
      idUsuario: row[0].toString(),
      email: row[1].toString(),
      nombreUsuario: row[2].toString(),
      passwordHash: row[3]?.toString(),
      rol: row[4]?.toString(),
      avatar: row[5]?.toString(),
    );
  }

  Future<Map<String, dynamic>> registrar(String password) async {
    try {
      final hash = Crypt.sha256(password).toString();
      
      final result = await Database.connection.execute(
        Sql.named('''
          INSERT INTO usuarios (nombre_usuario, email, password_hash, timestamp_ultimo_acceso)
          VALUES (@nombre, @email, @hash, NOW())
          RETURNING id_usuario, nombre_usuario, email, rol
        '''),
        parameters: {
          'nombre': objUsuario!.nombreUsuario,
          'email': objUsuario!.email,
          'hash': hash,
        }
      );

      if (result.isNotEmpty) {
        await Database.connection.execute(
          Sql.named('''
            INSERT INTO avatares (nombre, url_imagen)
            VALUES (@nombre, '🤠')
            ON CONFLICT (nombre) DO NOTHING
          '''),
          parameters: {'nombre': objUsuario!.nombreUsuario}
        );

        final row = result.first;
        return {
          'success': true,
          'message': 'Usuario registrado correctamente.',
          'usuario': {
            'idUsuario': row[0].toString(),
            'nombreUsuario': row[1].toString(),
            'email': row[2].toString(),
            'rol': row[3]?.toString(),
            'avatar': '🤠'
          }
        };
      }
      throw Exception("No se pudo registrar.");
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
