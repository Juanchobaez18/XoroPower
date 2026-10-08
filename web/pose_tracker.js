// MediaPipe Pose Tracker for Web
// Uses shoulder, elbow, wrist and hip landmarks to validate real arm movement.

window.webPoseTracker = {
  camera: null,
  pose: null,
  startTimeout: null,
  startAttempt: 0,
  hands: null,
  detectorReady: false,
  processingFrame: false,
  config: {
    smoothing: 0.58,
    minimumTravel: 0.045,
    minimumFrameTravel: 0.00025,
    minimumVisibility: 0.35,
    cooldownMs: 230,
    calibrationMs: 800
  },

  startTracking: function(videoElement) {
    if (!videoElement) return;
    this.stopTracking();
    const attempt = ++this.startAttempt;
    this.hands = {
      left: this.createHandState(),
      right: this.createHandState()
    };
    this.detectorReady = false;
    this.processingFrame = false;

    if (!window.isSecureContext) {
      this.reportError('La cámara requiere HTTPS o localhost.');
      return;
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.reportError('Este navegador no permite acceder a la cámara.');
      return;
    }
    if (typeof Pose === 'undefined' || typeof Camera === 'undefined') {
      this.reportError('No se pudieron cargar las librerías de detección. Recarga la página.');
      return;
    }

    try {
      this.pose = new Pose({
        locateFile: file => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`
      });
      this.pose.setOptions({
        modelComplexity: 0,
        smoothLandmarks: true,
        enableSegmentation: false,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5
      });
      this.pose.onResults(results => {
        if (attempt === this.startAttempt) {
          this.detectorReady = true;
          this.onResults(results);
        }
      });

      this.startTimeout = setTimeout(() => {
        if (attempt !== this.startAttempt) return;
        this.stopTracking();
        this.reportError(
          'La cámara o el detector tardaron demasiado. Revisa los permisos e inténtalo de nuevo.'
        );
      }, 30000);

      const pose = this.pose;
      const initializeDetector = pose.initialize().then(() => {
        if (attempt === this.startAttempt) this.detectorReady = true;
      });

      this.camera = new Camera(videoElement, {
        onFrame: async () => {
          if (
            !this.pose ||
            !this.detectorReady ||
            this.processingFrame ||
            attempt !== this.startAttempt
          ) {
            return;
          }
          this.processingFrame = true;
          try {
            await this.pose.send({image: videoElement});
          } catch (error) {
            console.warn('Error procesando imagen para detectar movimientos:', error);
          } finally {
            this.processingFrame = false;
          }
        },
        width: 640,
        height: 480
      });
      const startCamera = this.camera.start();

      Promise.all([initializeDetector, startCamera]).then(() => {
        if (attempt !== this.startAttempt) return;
        clearTimeout(this.startTimeout);
        this.startTimeout = null;
        if (window.onWebPoseCameraReady) window.onWebPoseCameraReady();
      }).catch(error => {
        if (attempt !== this.startAttempt) return;
        this.stopTracking();
        this.reportError(`No se pudo activar la cámara: ${error}`);
      });
    } catch (error) {
      this.stopTracking();
      this.reportError(`No se pudo iniciar la detección: ${error}`);
    }
  },

  createHandState: function() {
    return {
      filteredY: null,
      previousY: null,
      candidateStartY: null,
      candidateDirection: null,
      lastDirection: null,
      lastEventAt: 0,
      samples: [],
      calibrationStartedAt: null,
      calibrated: false,
      reportedStatus: null
    };
  },

  reportError: function(error) {
    if (window.onWebPoseCameraError) window.onWebPoseCameraError(error);
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
    const landmarks = results.poseLandmarks;
    if (!landmarks) {
      for (const side of ['left', 'right']) {
        const state = this.hands[side];
        state.filteredY = null;
        state.previousY = null;
        state.candidateStartY = null;
        state.candidateDirection = null;
        state.samples = [];
        state.calibrationStartedAt = null;
        state.calibrated = false;
        this.reportHandStatus(side, 'No detectada');
      }
      return;
    }

    const now = performance.now();
    this.updateHand('left', landmarks, now);
    this.updateHand('right', landmarks, now);
  },

  updateHand: function(side, landmarks, now) {
    const isLeft = side === 'left';
    const shoulder = landmarks[isLeft ? 11 : 12];
    const elbow = landmarks[isLeft ? 13 : 14];
    const wrist = landmarks[isLeft ? 15 : 16];
    const leftHip = landmarks[23];
    const rightHip = landmarks[24];
    const state = this.hands[side];
    const visible = point =>
      point && (point.visibility == null ||
        point.visibility >= this.config.minimumVisibility);

    if (!visible(shoulder) || !visible(wrist)) {
      state.filteredY = null;
      state.previousY = null;
      state.candidateStartY = null;
      state.candidateDirection = null;
      state.samples = [];
      state.calibrationStartedAt = null;
      state.calibrated = false;
      this.reportHandStatus(side, 'No detectada');
      return;
    }
    this.reportHandStatus(side, state.calibrated ? 'Lista' : 'Calibrando');

    const shoulderY = shoulder.y;
    const armY = visible(elbow)
      ? wrist.y * 0.65 + elbow.y * 0.35
      : wrist.y;
    const torsoHeight = visible(leftHip) && visible(rightHip)
      ? Math.max(0.16, Math.abs((leftHip.y + rightHip.y) / 2 - shoulderY))
      : 0.3;
    const position = (armY - shoulderY) / torsoHeight;
    state.filteredY = state.filteredY == null
      ? position
      : state.filteredY * this.config.smoothing +
        position * (1 - this.config.smoothing);

    if (state.previousY == null) {
      state.previousY = state.filteredY;
      state.calibrationStartedAt = now;
      state.samples.push(state.filteredY);
      return;
    }

    const delta = state.filteredY - state.previousY;
    state.previousY = state.filteredY;

    if (!state.calibrated) {
      if (Math.abs(delta) <= 0.012) {
        state.samples.push(state.filteredY);
        if (state.samples.length > 40) state.samples.shift();
      } else {
        state.samples = [state.filteredY];
        state.calibrationStartedAt = now;
      }
      if (
        state.calibrationStartedAt != null &&
        now - state.calibrationStartedAt >= this.config.calibrationMs &&
        state.samples.length >= 8
      ) {
        const sorted = [...state.samples].sort((a, b) => a - b);
        state.baselineY = sorted[Math.floor(sorted.length / 2)];
        state.calibrated = true;
        state.candidateStartY = state.filteredY;
        this.reportHandStatus(side, 'Lista');
      }
      return;
    }

    if (Math.abs(delta) < this.config.minimumFrameTravel) return;
    const direction = delta < 0 ? 'up' : 'down';

    if (state.lastDirection === direction) return;
    if (state.lastDirection && direction !== state.lastDirection) {
      state.lastDirection = null;
      state.candidateDirection = null;
      state.candidateStartY = state.filteredY - delta;
    }
    if (state.candidateDirection !== direction) {
      state.candidateDirection = direction;
      state.candidateStartY = state.filteredY - delta;
    }

    const traveled = Math.abs(state.filteredY - state.candidateStartY);
    if (
      traveled >= this.config.minimumTravel &&
      now - state.lastEventAt >= this.config.cooldownMs
    ) {
      state.lastEventAt = now;
      state.lastDirection = direction;
      state.candidateDirection = null;
      state.candidateStartY = state.filteredY;
      this.dispatchShakeEvent(side, direction);
    }
  },

  dispatchShakeEvent: function(side, direction) {
    if (window.onWebPoseShakeDetected) {
      window.onWebPoseShakeDetected(side, direction);
    }
  },

  reportHandStatus: function(side, status) {
    const state = this.hands && this.hands[side];
    if (!state || state.reportedStatus === status) return;
    state.reportedStatus = status;
    if (window.onWebPoseHandStatus) {
      window.onWebPoseHandStatus(side, status);
    }
  }
};
