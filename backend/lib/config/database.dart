import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  static late Connection connection;

  static Future<void> init() async {
    var env = DotEnv(includePlatformEnvironment: true)..load();
    String connectionString = env['DATABASE_URL'] ?? 'postgres://postgres:1234@localhost:5432/xoropower';

    try {
      // Usar postgres para conectarse (usando Connection en v3)
      final endpoint = Endpoint(
        host: 'localhost',
        database: 'xoropower',
        username: 'postgres',
        password: '123', // Usar el uri de env en produccion real, parseando
        port: 5432,
      );
      
      // Intentar conectarse de manera sencilla (ejemplo estático)
      // En una app real, deberíamos parsear connectionString
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
