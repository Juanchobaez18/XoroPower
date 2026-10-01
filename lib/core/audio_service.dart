import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  final AudioPlayer _metronomePlayer = AudioPlayer();
  final AudioPlayer _hitPlayer = AudioPlayer();
  final AudioPlayer _missPlayer = AudioPlayer();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Usamos sonidos públicos de prueba (como beeps y clics).
      // En producción, reemplazarías 'setUrl' por 'setAsset' (ej. setAsset('assets/audio/metronome.mp3'))

      // Metrónomo (clic corto)
      await _metronomePlayer.setUrl(
        'https://actions.google.com/sounds/v1/impacts/wood_block_hit.ogg',
      );

      // Hit (campana o sonido agradable)
      await _hitPlayer.setUrl(
        'https://actions.google.com/sounds/v1/cartoon/cartoon_boing.ogg',
      );

      // Miss (sonido grave)
      await _missPlayer.setUrl(
        'https://actions.google.com/sounds/v1/cartoon/slip.ogg',
      );

      _isInitialized = true;
    } catch (e) {
      print("Error inicializando audio (posiblemente sin conexión): $e");
    }
  }

  Future<void> playMetronome() async {
    try {
      await _metronomePlayer.seek(Duration.zero);
      await _metronomePlayer.play();
    } catch (e) {
      // Ignorar si falla por red
    }
  }

  Future<void> stopMetronome() async {
    try {
      await _metronomePlayer.stop();
    } catch (_) {
      // El reproductor puede no haberse inicializado todavía.
    }
  }

  Future<void> playHit() async {
    try {
      await _hitPlayer.seek(Duration.zero);
      await _hitPlayer.play();
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> playMiss() async {
    try {
      await _missPlayer.seek(Duration.zero);
      await _missPlayer.play();
    } catch (e) {
      // Ignorar
    }
  }

  void dispose() {
    _metronomePlayer.dispose();
    _hitPlayer.dispose();
    _missPlayer.dispose();
  }
}
