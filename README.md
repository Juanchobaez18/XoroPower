# XoroPower

Aplicación Flutter para aprender maracas llaneras mediante lecciones guiadas,
detección de movimientos y seguimiento del progreso en Supabase.

## Desarrollo

Instala Flutter estable y ejecuta:

```powershell
flutter pub get
flutter run
```

La aplicación usa el proyecto Supabase configurado en `lib/main.dart`. La clave
`publishable` es pública por diseño; nunca configures una clave `service_role`
en la aplicación. En Supabase, protege las tablas con políticas RLS antes de
publicar.

## Preparación de una versión Android

El identificador permanente configurado es `com.xoropower.app` en Android,
iOS, macOS y Linux. Confirma que este identificador esté disponible y
pertenezca a la organización antes de registrar la aplicación en las tiendas;
cambiarlo después de publicar crea una aplicación distinta.

Las versiones `release` no usan la firma de depuración. El build exige un
keystore de lanzamiento guardado localmente.

1. Guarda el keystore de carga en `android/` y crea `android/key.properties`
   localmente:

   ```properties
   storeFile=upload-keystore.jks
   keyAlias=upload
   storePassword=REEMPLAZAR_LOCALMENTE
   keyPassword=REEMPLAZAR_LOCALMENTE
   ```

   `key.properties` y los keystores están excluidos de Git. Conserva copias
   seguras del keystore; no se pueden recuperar desde el APK.
2. Genera el paquete:

   ```powershell
   Push-Location android
   .\gradlew.bat bundleRelease
   Pop-Location
   ```

Incrementa `version` en `pubspec.yaml` para cada publicación. La firma iOS
también requiere que registres el bundle ID en Apple Developer y configures el
equipo de firma en Xcode.

## Supabase

Antes de habilitar la eliminación de módulos en el panel de administración,
ejecuta
[`20261005190000_delete_module_with_content.sql`](supabase/migrations/20261005190000_delete_module_with_content.sql)
en el SQL Editor del proyecto Supabase. La función elimina en una sola
transacción el módulo, sus ejercicios y el progreso relacionado, y sólo permite
la operación a usuarios con rol de administrador.

Revisa también que todas las tablas consultadas por la aplicación tengan
políticas RLS verificadas con cuentas de estudiante y administrador. La clave
publishable no sustituye esas políticas.

## Alcance del backend

`backend/` contiene un servicio Shelf independiente con una ruta de salud. La
aplicación Flutter consume Supabase directamente; este servicio aún no
implementa la API de la aplicación y no debe desplegarse como backend funcional
de producción sin completar y proteger sus rutas, base de datos, TLS y política
de CORS.
