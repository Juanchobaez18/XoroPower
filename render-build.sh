#!/bin/bash

# Salir si ocurre algún error
set -e

# Descargar Flutter (versión estable)
echo "Descargando Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

# Añadir Flutter al PATH temporalmente para este build
export PATH="$PATH:`pwd`/flutter/bin"

# Limpiar y obtener dependencias
echo "Obteniendo dependencias..."
flutter clean
flutter pub get

# Compilar para la web
echo "Compilando Flutter Web..."
flutter build web --release

echo "¡Compilación terminada!"
