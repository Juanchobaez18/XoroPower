import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'pose_detector_service.dart';

class WebPoseService {
  final Function(DetectedMotion) onShakeDetected;

  WebPoseService({required this.onShakeDetected}) {
    // Bind the global JS callback to our Dart function
    js.context['onWebPoseShakeDetected'] = (String sideStr, String directionStr) {
      final hand = sideStr == 'left' ? HandSide.left : HandSide.right;
      final direction = directionStr == 'up' ? MotionDirection.up : MotionDirection.down;
      onShakeDetected(DetectedMotion(hand: hand, direction: direction));
    };
  }

  Widget buildVideoElement(String viewId) {
    // Register the view factory for the video element
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final videoElement = html.VideoElement()
        ..id = viewId
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // Mirror for natural feel
      return videoElement;
    });

    return HtmlElementView(viewType: viewId);
  }

  void startTracking(String videoElementId) {
    final videoEl = html.document.getElementById(videoElementId);
    if (videoEl != null) {
      js.context['webPoseTracker'].callMethod('startTracking', [videoEl]);
    } else {
      debugPrint("Error: Video element '\$videoElementId' not found in DOM.");
    }
  }

  void stopTracking() {
    js.context['webPoseTracker'].callMethod('stopTracking');
    js.context['onWebPoseShakeDetected'] = null;
  }
}
