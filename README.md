# xoropower

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase: eliminación de módulos

Antes de habilitar la eliminación de módulos en el panel de administración,
ejecuta
[`20261005190000_delete_module_with_content.sql`](supabase/migrations/20261005190000_delete_module_with_content.sql)
en el SQL Editor del proyecto Supabase. La función elimina en una sola
transacción el módulo, sus ejercicios y el progreso relacionado, y sólo permite
la operación a usuarios con rol de administrador.
