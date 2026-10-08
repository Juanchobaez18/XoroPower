import 'package:flutter/services.dart';

Future<void> initializeAudioFeedback() async {}

Future<void> playAudioFeedback(String kind) async {
  await SystemSound.play(SystemSoundType.click);
}
