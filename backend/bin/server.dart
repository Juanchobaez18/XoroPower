import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/config/database.dart';

Response _healthHandler(Request request) {
  return Response.ok(
    '{"status":"ok", "service":"xoropower-api"}',
    headers: {'Content-Type': 'application/json'},
  );
}

Handler buildHandler({required String allowedOrigin}) {
  final router = Router();
  router.get('/health', _healthHandler);

  return Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        (innerHandler) => (request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok(
              '',
              headers: {
                'Access-Control-Allow-Origin': allowedOrigin,
                'Access-Control-Allow-Methods':
                    'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers':
                    'Origin, Content-Type, Authorization',
              },
            );
          }
          final response = await innerHandler(request);
          return response.change(
            headers: {'Access-Control-Allow-Origin': allowedOrigin},
          );
        },
      )
      .addHandler(router.call);
}

Future<void> main(List<String> args) async {
  final rawAllowedOrigin = Platform.environment['CORS_ALLOWED_ORIGIN'];
  if (rawAllowedOrigin == null || rawAllowedOrigin.isEmpty) {
    throw StateError('CORS_ALLOWED_ORIGIN must be configured.');
  }
  final allowedOriginUri = Uri.tryParse(rawAllowedOrigin);
  if (allowedOriginUri == null ||
      !{'http', 'https'}.contains(allowedOriginUri.scheme) ||
      allowedOriginUri.host.isEmpty ||
      (allowedOriginUri.path.isNotEmpty && allowedOriginUri.path != '/')) {
    throw const FormatException('CORS_ALLOWED_ORIGIN must be a valid origin.');
  }

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080');
  if (port == null || port < 1 || port > 65535) {
    throw const FormatException('PORT must be between 1 and 65535.');
  }

  await Database.init();
  final server = await serve(
    buildHandler(allowedOrigin: allowedOriginUri.origin),
    InternetAddress.anyIPv4,
    port,
  );
  print('Servidor escuchando en http://${server.address.host}:${server.port}');
}
