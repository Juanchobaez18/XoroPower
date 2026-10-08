import 'dart:js' as js;

Future<void> initializeAudioFeedback() async {
  final audio = js.context['xoroAudioFeedback'];
  if (audio == null) {
    throw StateError('No se cargó el servicio local de audio.');
  }
  audio.callMethod('initialize');
}

Future<void> playAudioFeedback(String kind) async {
  final audio = js.context['xoroAudioFeedback'];
  if (audio == null) {
    throw StateError('No se cargó el servicio local de audio.');
  }
  audio.callMethod('play', [kind]);
}
