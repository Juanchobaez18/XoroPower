import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

class Database {
  static late Connection connection;

  static Future<void> init() async {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final rawDatabaseUrl = env['DATABASE_URL'];
    if (rawDatabaseUrl == null || rawDatabaseUrl.isEmpty) {
      throw StateError('DATABASE_URL must be configured.');
    }

    final connectionUri = Uri.parse(rawDatabaseUrl);
    if (!connectionUri.hasAuthority ||
        connectionUri.host.isEmpty ||
        connectionUri.pathSegments.isEmpty ||
        !{'postgres', 'postgresql'}.contains(connectionUri.scheme)) {
      throw const FormatException(
        'DATABASE_URL is not a valid PostgreSQL URI.',
      );
    }

    final credentials = connectionUri.userInfo.split(':');
    if (credentials.first.isEmpty) {
      throw const FormatException('DATABASE_URL must include a database user.');
    }
    final sslMode = switch (env['DATABASE_SSL_MODE']?.toLowerCase()) {
      null || '' || 'verify-full' => SslMode.verifyFull,
      'require' => SslMode.require,
      'disable' => SslMode.disable,
      final value => throw FormatException(
        'Unsupported DATABASE_SSL_MODE: $value',
      ),
    };

    try {
      final endpoint = Endpoint(
        host: connectionUri.host,
        database: connectionUri.pathSegments.first,
        username: Uri.decodeComponent(credentials.first),
        password: credentials.length > 1
            ? Uri.decodeComponent(credentials.skip(1).join(':'))
            : '',
        port: connectionUri.hasPort ? connectionUri.port : 5432,
      );

      connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(sslMode: sslMode),
      );
      print('Conexión a PostgreSQL establecida correctamente.');
    } catch (error) {
      print('Error al conectar a PostgreSQL: $error');
      rethrow;
    }
  }
}
