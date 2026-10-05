import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static late Connection connection;

  static Future<void> init() async {
    var env = DotEnv(includePlatformEnvironment: true)..load();
    final connectionUri = Uri.parse(
      env['DATABASE_URL'] ??
          'postgres://postgres:1234@localhost:5432/xoropower',
    );
    final credentials = connectionUri.userInfo.split(':');

    try {
      final endpoint = Endpoint(
        host: connectionUri.host,
        database: connectionUri.pathSegments.isEmpty
            ? 'xoropower'
            : connectionUri.pathSegments.first,
        username: Uri.decodeComponent(credentials.first),
        password: credentials.length > 1
            ? Uri.decodeComponent(credentials.skip(1).join(':'))
            : '',
        port: connectionUri.hasPort ? connectionUri.port : 5432,
      );

      connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
      print('Conexión a PostgreSQL establecida correctamente.');
    } catch (e) {
      print('Error al conectar a PostgreSQL: $e');
      rethrow;
    }
  }
}
