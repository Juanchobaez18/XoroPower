// MediaPipe Pose Tracker for Web
// This script runs in the browser and sends shake events to Flutter

window.webPoseTracker = {
  camera: null,
  pose: null,
  startTimeout: null,
  startAttempt: 0,
  
  lastLeftWristY: 0,
  lastRightWristY: 0,
  lastTimestamp: 0,
  
  lastLeftShakeTime: 0,
  lastRightShakeTime: 0,
  
  shakeVelocityThreshold: 0.001,
  
  startTracking: function(videoElement) {
    if (!videoElement) return;
    this.stopTracking();
    const attempt = ++this.startAttempt;

    try {
      if (!window.isSecureContext) {
        throw new Error(
          'El navegador solo permite usar la cámara en HTTPS o en localhost.'
        );
      }
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error(
          'Este navegador no permite acceder a la cámara. Prueba con Chrome o Edge actualizado.'
        );
      }
      if (typeof Pose === 'undefined' || typeof Camera === 'undefined') {
        throw new Error('No se pudieron cargar las librerías de cámara.');
      }

      this.pose = new Pose({locateFile: (file) => {
        return `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`;
      }});

      this.pose.setOptions({
        modelComplexity: 0,
        smoothLandmarks: true,
        enableSegmentation: false,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5
      });

      this.pose.onResults(this.onResults.bind(this));

      this.camera = new Camera(videoElement, {
        onFrame: async () => {
          if (this.pose) {
            await this.pose.send({image: videoElement});
          }
        },
        width: 640,
        height: 480
      });

      this.startTimeout = setTimeout(() => {
        if (attempt !== this.startAttempt) return;
        this.stopTracking();
        if (window.onWebPoseCameraError) {
          window.onWebPoseCameraError(
            'La cámara tardó demasiado en activarse. Revisa los permisos del navegador e inténtalo de nuevo.'
          );
        }
      }, 20000);

      this.camera.start()
        .then(() => {
          if (attempt !== this.startAttempt) return;
          clearTimeout(this.startTimeout);
          this.startTimeout = null;
          if (window.onWebPoseCameraReady) window.onWebPoseCameraReady();
        })
        .catch((error) => {
          if (attempt !== this.startAttempt) return;
          this.stopTracking();
          if (window.onWebPoseCameraError) {
            window.onWebPoseCameraError(`No se pudo activar la cámara: ${error}`);
          }
        });
    } catch (error) {
      this.stopTracking();
      if (window.onWebPoseCameraError) {
        window.onWebPoseCameraError(`No se pudo iniciar la detección: ${error}`);
      }
    }
  },
  
  stopTracking: function() {
    this.startAttempt++;
    if (this.startTimeout) {
      clearTimeout(this.startTimeout);
      this.startTimeout = null;
    }
    if (this.camera) {
      this.camera.stop();
      this.camera = null;
    }
    if (this.pose) {
      this.pose.close();
      this.pose = null;
    }
  },
  
  onResults: function(results) {
    if (!results.poseLandmarks) return;
    
    // MediaPipe Pose Landmarks: 15 = Left Wrist, 16 = Right Wrist
    const leftWrist = results.poseLandmarks[15];
    const rightWrist = results.poseLandmarks[16];
    
    const currentTime = Date.now();
    if (this.lastTimestamp === 0) {
      this.lastTimestamp = currentTime;
      if (leftWrist) this.lastLeftWristY = leftWrist.y;
      if (rightWrist) this.lastRightWristY = rightWrist.y;
      return;
    }
    
    const dt = currentTime - this.lastTimestamp;
    if (dt === 0) return;
    
    // Calculate Left Velocity
    if (leftWrist) {
      const velocity = (leftWrist.y - this.lastLeftWristY) / dt;
      if (Math.abs(velocity) > this.shakeVelocityThreshold && (currentTime - this.lastLeftShakeTime) > 300) {
        this.lastLeftShakeTime = currentTime;
        this.dispatchShakeEvent('left', velocity < 0 ? 'up' : 'down');
      }
      this.lastLeftWristY = leftWrist.y;
    }
    
    // Calculate Right Velocity
    if (rightWrist) {
      const velocity = (rightWrist.y - this.lastRightWristY) / dt;
      if (Math.abs(velocity) > this.shakeVelocityThreshold && (currentTime - this.lastRightShakeTime) > 300) {
        this.lastRightShakeTime = currentTime;
        this.dispatchShakeEvent('right', velocity < 0 ? 'up' : 'down');
      }
      this.lastRightWristY = rightWrist.y;
    }
    
    this.lastTimestamp = currentTime;
  },
  
  dispatchShakeEvent: function(side, direction) {
    if (window.onWebPoseShakeDetected) {
      window.onWebPoseShakeDetected(side, direction);
    }
  }
};
