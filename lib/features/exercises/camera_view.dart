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
  String? _cameraError;

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
          if (mounted) _webPoseService?.startTracking('webPoseVideo');
        });
      });
    } else {
      _poseService = PoseDetectorService(onShakeDetected: widget.onShake);
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 20),
      );
      if (cameras.isEmpty) {
        _reportCameraError('No se encontró una cámara en este dispositivo.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
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
      _controller = controller;

      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller
          .startImageStream(_processCameraImage)
          .timeout(const Duration(seconds: 20));
      setState(() => _isReady = true);
      _reportCameraReady(true);
    } catch (e) {
      _reportCameraError('No se pudo activar la cámara: $e');
      if (controller != null) {
        if (identical(_controller, controller)) _controller = null;
        try {
          await controller.dispose();
        } catch (disposeError) {
          debugPrint('Error al liberar la cámara: $disposeError');
        }
      }
    }
  }

  void _reportCameraReady(bool ready) {
    if (ready && mounted) {
      setState(() => _cameraError = null);
    }
    widget.onCameraReady?.call(ready);
  }

  void _reportCameraError(String error) {
    if (mounted) {
      setState(() {
        _cameraError = error;
        _isReady = true;
      });
    }
    widget.onCameraReady?.call(false);
    widget.onCameraError?.call(error);
  }

  void _retryCamera() {
    setState(() {
      _cameraError = null;
      _isReady = kIsWeb;
    });
    widget.onCameraReady?.call(false);
    if (kIsWeb) {
      _webPoseService?.stopTracking(clearCallbacks: false);
      _webPoseService?.startTracking('webPoseVideo');
    } else {
      _initializeCamera();
    }
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

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _retryCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar cámara'),
              ),
            ],
          ),
        ),
      );
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
