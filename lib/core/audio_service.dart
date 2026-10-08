import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_feedback_stub.dart'
    if (dart.library.html) 'audio_feedback_web.dart' as audio_feedback;

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  bool _isInitialized = false;
  Future<void>? _initialization;

  Future<void> init() {
    if (_isInitialized) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await audio_feedback.initializeAudioFeedback();
      _isInitialized = true;
    } catch (error) {
      _initialization = null;
      debugPrint('No se pudo iniciar el audio local: $error');
      rethrow;
    }
  }

  Future<void> playMetronome() => _play('metronome');

  Future<void> stopMetronome() async {}

  Future<void> playHit() => _play('hit');

  Future<void> playMiss() => _play('miss');

  Future<void> _play(String kind) async {
    try {
      await audio_feedback.playAudioFeedback(kind);
    } catch (error) {
      debugPrint('No se pudo reproducir el sonido local ($kind): $error');
    }
  }

  void dispose() {}
}
