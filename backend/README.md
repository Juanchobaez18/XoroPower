# XoroPower API (prototipo)

Este paquete contiene un servidor Shelf mínimo. Actualmente expone sólo
`GET /health`; la aplicación Flutter no lo consume y usa Supabase directamente.
No desplegar este servicio como API de producción todavía.

## Ejecución local

Requiere Dart estable y PostgreSQL. Configura `DATABASE_URL` y
`CORS_ALLOWED_ORIGIN` en el entorno antes de iniciar el servidor. PostgreSQL
usa verificación completa de certificados por defecto (`verify-full`); para una
base local sin TLS, configura `DATABASE_SSL_MODE=disable` sólo en desarrollo.
Ejecuta desde esta carpeta:

```powershell
dart pub get
dart run bin/server.dart
```

El servidor usa `PORT` si está definido; de lo contrario escucha en el puerto
8080. Comprueba el estado con `GET /health`.

## Bloqueos para producción

- Añadir y proteger con autenticación/autorización las rutas que necesita la
  aplicación.
- Añadir pruebas de integración para base de datos, permisos y rutas.
