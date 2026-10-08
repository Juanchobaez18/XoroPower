import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'pose_detector_service.dart';

class WebPoseService {
  static const String _videoViewId = 'webPoseVideo';
  static bool _videoViewRegistered = false;

  final Function(DetectedMotion) onShakeDetected;
  final ValueChanged<bool>? onCameraReady;
  final ValueChanged<String>? onCameraError;
  final ValueChanged<String>? onDetectionStatus;
  html.VideoElement? _videoElement;
  String _leftHandStatus = 'Buscando';
  String _rightHandStatus = 'Buscando';

  WebPoseService({
    required this.onShakeDetected,
    this.onCameraReady,
    this.onCameraError,
    this.onDetectionStatus,
  }) {
    if (!_videoViewRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_videoViewId, (int id) {
        return html.VideoElement()
          ..id = _videoViewId
          ..autoplay = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.transform = 'scaleX(-1)';
      });
      _videoViewRegistered = true;
    }

    // Bind the global JS callback to our Dart function
    js.context['onWebPoseShakeDetected'] =
        (String sideStr, String directionStr) {
          final hand = sideStr == 'left' ? HandSide.left : HandSide.right;
          final direction = directionStr == 'up'
              ? MotionDirection.up
              : MotionDirection.down;
          onShakeDetected(DetectedMotion(hand: hand, direction: direction));
        };
    js.context['onWebPoseCameraReady'] = () => onCameraReady?.call(true);
    js.context['onWebPoseCameraError'] = (String error) {
      onCameraReady?.call(false);
      onCameraError?.call(error);
    };
    js.context['onWebPoseHandStatus'] = (String side, String status) {
      if (side == 'right') {
        _rightHandStatus = status;
      } else {
        _leftHandStatus = status;
      }
      onDetectionStatus?.call(
        'Derecha: $_rightHandStatus · Izquierda: $_leftHandStatus',
      );
    };
  }

  Widget buildVideoElement(String viewId) {
    return HtmlElementView(
      viewType: viewId,
      onPlatformViewCreated: (platformViewId) {
        final element = ui_web.platformViewRegistry.getViewById(platformViewId);
        if (element is! html.VideoElement) {
          final error = 'No se pudo crear el elemento de video de la cámara.';
          onCameraReady?.call(false);
          onCameraError?.call(error);
          debugPrint(error);
          return;
        }
        _videoElement = element;
        startTracking(viewId);
      },
    );
  }

  void startTracking(String videoElementId) {
    final videoEl = _videoElement;
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
      js.context['onWebPoseHandStatus'] = null;
      _videoElement = null;
    }
  }
}
