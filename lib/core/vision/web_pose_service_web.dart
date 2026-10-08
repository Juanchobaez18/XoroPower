import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'pose_detector_service.dart';

class WebPoseService {
  final Function(DetectedMotion) onShakeDetected;
  final ValueChanged<bool>? onCameraReady;
  final ValueChanged<String>? onCameraError;

  WebPoseService({
    required this.onShakeDetected,
    this.onCameraReady,
    this.onCameraError,
  }) {
    // Bind the global JS callback to our Dart function
    js.context['onWebPoseShakeDetected'] = (String sideStr, String directionStr) {
      final hand = sideStr == 'left' ? HandSide.left : HandSide.right;
      final direction = directionStr == 'up' ? MotionDirection.up : MotionDirection.down;
      onShakeDetected(DetectedMotion(hand: hand, direction: direction));
    };
    js.context['onWebPoseCameraReady'] = () => onCameraReady?.call(true);
    js.context['onWebPoseCameraError'] = (String error) {
      onCameraReady?.call(false);
      onCameraError?.call(error);
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
    final tracker = js.context['webPoseTracker'];
    if (videoEl == null) {
      final error = "No se encontró el elemento de video '$videoElementId'.";
      onCameraReady?.call(false);
      onCameraError?.call(error);
      debugPrint(error);
      return;
    }
    if (tracker == null) {
      const error =
          'No se cargó el servicio de cámara. Recarga la página e inténtalo de nuevo.';
      onCameraReady?.call(false);
      onCameraError?.call(error);
      debugPrint(error);
      return;
    }

    try {
      tracker.callMethod('startTracking', [videoEl]);
    } catch (error) {
      final message = 'No se pudo iniciar la detección de cámara: $error';
      onCameraReady?.call(false);
      onCameraError?.call(message);
      debugPrint(message);
    }
  }

  void stopTracking({bool clearCallbacks = true}) {
    final tracker = js.context['webPoseTracker'];
    if (tracker != null) tracker.callMethod('stopTracking');
    if (clearCallbacks) {
      js.context['onWebPoseShakeDetected'] = null;
      js.context['onWebPoseCameraReady'] = null;
      js.context['onWebPoseCameraError'] = null;
    }
  }
}
