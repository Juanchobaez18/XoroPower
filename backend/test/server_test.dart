import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../bin/server.dart';

void main() {
  final handler = buildHandler(allowedOrigin: 'https://app.example.com');

  test('Health endpoint reports the service status', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, 200);
    expect(await response.readAsString(), contains('"status":"ok"'));
    expect(response.headers['content-type'], contains('application/json'));
  });

  test('Unknown routes return 404', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/unknown')),
    );

    expect(response.statusCode, 404);
  });

  test('Preflight requests receive CORS headers', () async {
    final response = await handler(
      Request('OPTIONS', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, 200);
    expect(
      response.headers['access-control-allow-origin'],
      'https://app.example.com',
    );
  });
}
