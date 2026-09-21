import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum HandSide { left, right }

class PoseDetectorService {
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  
  bool _isProcessing = false;
  
  // Posiciones anteriores para calcular velocidad
  double _lastLeftWristY = 0;
  double _lastRightWristY = 0;
  int _lastTimestamp = 0;
  
  // Umbral de velocidad hacia abajo (pixels por milisegundo)
  // Se requerirá calibración fina, empezamos con 0.8 como un golpe brusco.
  final double shakeVelocityThreshold = 0.8; 
  
  // Evitar disparos múltiples por el mismo movimiento (cooldown de 300ms)
  int _lastLeftShakeTime = 0;
  int _lastRightShakeTime = 0;
  
  final Function(HandSide) onShakeDetected;
  
  PoseDetectorService({required this.onShakeDetected});

  Future<void> processImage(InputImage inputImage) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) return;

      final pose = poses.first;
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      if (_lastTimestamp == 0) {
        _lastTimestamp = currentTime;
        if (leftWrist != null) _lastLeftWristY = leftWrist.y;
        if (rightWrist != null) _lastRightWristY = rightWrist.y;
        return;
      }

      final dt = currentTime - _lastTimestamp;
      if (dt == 0) return;

      // Calcular velocidad de la muñeca izquierda (roja)
      if (leftWrist != null) {
        final velocity = (leftWrist.y - _lastLeftWristY) / dt;
        // Si la velocidad hacia abajo es mayor al umbral y pasó el cooldown
        if (velocity > shakeVelocityThreshold && (currentTime - _lastLeftShakeTime) > 300) {
          _lastLeftShakeTime = currentTime;
          onShakeDetected(HandSide.left);
        }
        _lastLeftWristY = leftWrist.y;
      }

      // Calcular velocidad de la muñeca derecha (azul)
      if (rightWrist != null) {
        final velocity = (rightWrist.y - _lastRightWristY) / dt;
        if (velocity > shakeVelocityThreshold && (currentTime - _lastRightShakeTime) > 300) {
          _lastRightShakeTime = currentTime;
          onShakeDetected(HandSide.right);
        }
        _lastRightWristY = rightWrist.y;
      }

      _lastTimestamp = currentTime;
    } catch (e) {
      debugPrint('Error procesando pose: \$e');
    } finally {
      _isProcessing = false;
    }
  }
  
  void dispose() {
    _poseDetector.close();
  }
}
