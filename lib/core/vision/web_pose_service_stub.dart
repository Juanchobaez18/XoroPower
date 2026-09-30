import 'package:flutter/material.dart';
import 'pose_detector_service.dart';

class WebPoseService {
  final Function(DetectedMotion) onShakeDetected;

  WebPoseService({required this.onShakeDetected});

  Widget buildVideoElement(String viewId) {
    return const SizedBox.shrink(); // Not used on mobile
  }

  void startTracking(String videoElementId) {
    // No-op on mobile
  }

  void stopTracking() {
    // No-op on mobile
  }
}
