import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import '../lib/config/database.dart';

// Rutas (Ejemplo básico para Auth, se extenderá)
Response _echoHandler(Request request) {
  return Response.ok('{"status":"ok", "service":"xoropower-api"}', headers: {'Content-Type': 'application/json'});
}

void main(List<String> args) async {
  // Inicializar Base de Datos
  try {
    await Database.init();
  } catch (e) {
    print('No se pudo inicializar la base de datos (probablemente falta configuración): \$e');
  }

  // Configurar Enrutador
  final router = Router();
  router.get('/health', _echoHandler);
  
  // Agregar middleware de CORS y Logger
  final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware((innerHandler) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
          });
        }
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
        });
      })
      .addHandler(router.call);

  // Iniciar servidor
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(pipeline, InternetAddress.anyIPv4, port);
  print('Servidor escuchando en http://\${server.address.host}:\${server.port}');
}
