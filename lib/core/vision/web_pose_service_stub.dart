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
  });

  Widget buildVideoElement(String viewId) {
    return const SizedBox.shrink(); // Not used on mobile
  }

  void startTracking(String videoElementId) {
    // No-op on mobile
  }

  void stopTracking({bool clearCallbacks = true}) {
    // No-op on mobile
  }
}
