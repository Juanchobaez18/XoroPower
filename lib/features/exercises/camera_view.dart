import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../core/vision/pose_detector_service.dart';
import '../../core/vision/web_pose_service.dart';

class CameraView extends StatefulWidget {
  final Function(DetectedMotion) onShake;
  final ValueChanged<bool>? onCameraReady;
  final ValueChanged<String>? onCameraError;
  final bool enableTapSimulation;

  const CameraView({
    super.key,
    required this.onShake,
    this.onCameraReady,
    this.onCameraError,
    this.enableTapSimulation = true,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  PoseDetectorService? _poseService;
  WebPoseService? _webPoseService;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webPoseService = WebPoseService(
        onShakeDetected: widget.onShake,
        onCameraReady: _reportCameraReady,
        onCameraError: _reportCameraError,
      );
      _isReady = true; // Permite que se dibuje el HtmlElementView
      // Esperar a que Flutter inserte el elemento en el DOM real del navegador
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _webPoseService?.startTracking('webPoseVideo');
        });
      });
    } else {
      _poseService = PoseDetectorService(onShakeDetected: widget.onShake);
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _reportCameraError('No se encontró una cámara en este dispositivo.');
        if (mounted) setState(() => _isReady = true);
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset
            .low, // Baja resolución para procesar frames muy rápido (60fps)
        enableAudio: false,
        imageFormatGroup: kIsWeb
            ? null
            : (defaultTargetPlatform == TargetPlatform.android
                  ? ImageFormatGroup.nv21
                  : ImageFormatGroup.bgra8888),
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (!kIsWeb) {
        await _controller!.startImageStream(_processCameraImage);
      }
      setState(() => _isReady = true);
      _reportCameraReady(true);
    } catch (e) {
      _reportCameraError('No se pudo activar la cámara: $e');
      if (mounted) setState(() => _isReady = true);
    }
  }

  void _reportCameraReady(bool ready) {
    widget.onCameraReady?.call(ready);
  }

  void _reportCameraError(String error) {
    widget.onCameraReady?.call(false);
    widget.onCameraError?.call(error);
  }

  void _processCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final camera = _controller!.description;

    final inputImageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: inputImageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

    // Enviar el frame al servicio de ML
    _poseService?.processImage(inputImage);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _webPoseService?.stopTracking();
    } else {
      _controller?.stopImageStream();
      _controller?.dispose();
      _poseService?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!kIsWeb && _controller?.value.isInitialized != true) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se pudo iniciar la cámara. Revisa los permisos e inténtalo de nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (kIsWeb) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _webPoseService?.buildVideoElement('webPoseVideo') ??
              const SizedBox.shrink(),
          if (widget.enableTapSimulation)
            GestureDetector(
              onTapDown: (details) {
                final width = MediaQuery.of(context).size.width;
                widget.onShake(
                  DetectedMotion(
                    hand: details.globalPosition.dx < width / 2
                        ? HandSide.left
                        : HandSide.right,
                    direction: MotionDirection.down,
                  ),
                );
              },
              child: const ColoredBox(color: Colors.transparent),
            ),
        ],
      );
    }

    return SizedBox.expand(child: CameraPreview(_controller!));
  }
}
