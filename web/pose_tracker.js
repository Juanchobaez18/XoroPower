// MediaPipe Pose Tracker for Web
// Uses shoulder, elbow, wrist and hip landmarks to validate real arm movement.

window.webPoseTracker = {
  camera: null,
  mediaStream: null,
  pose: null,
  startTimeout: null,
  detectorTimeout: null,
  startAttempt: 0,
  hands: null,
  detectorReady: false,
  cameraStreamReady: false,
  firstFrameProcessed: false,
  reportedReady: false,
  processingFrame: false,
  frameRequest: null,
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
    this.cameraStreamReady = false;
    this.firstFrameProcessed = false;
    this.reportedReady = false;
    this.processingFrame = false;
    this.reportHandStatus('left', 'Activando cámara');
    this.reportHandStatus('right', 'Activando cámara');

    if (!window.isSecureContext) {
      this.reportError('La cámara requiere HTTPS o localhost.');
      return;
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.reportError('Este navegador no permite acceder a la cámara.');
      return;
    }
    if (typeof Pose === 'undefined') {
      this.reportError('No se pudo cargar MediaPipe Pose. Revisa la conexión e inténtalo de nuevo.');
      return;
    }

    try {
      this.pose = new Pose({
        locateFile: file => `mediapipe/${file}`
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
          this.firstFrameProcessed = true;
          this.onResults(results);
          this.reportCameraReadyIfReady(attempt);
          clearTimeout(this.detectorTimeout);
          this.detectorTimeout = null;
        }
      });

      this.startTimeout = setTimeout(() => {
        if (attempt !== this.startAttempt) return;
        this.stopTracking();
        this.reportError('La cámara no respondió al permiso solicitado. Permite el acceso e inténtalo de nuevo.');
      }, 15000);

      const pose = this.pose;
      const initializeDetector = pose.initialize().then(() => {
        if (attempt !== this.startAttempt) return;
        this.detectorReady = true;
        this.reportHandStatus('left', 'Buscando');
        this.reportHandStatus('right', 'Buscando');
        this.scheduleFrame(videoElement, attempt);
        this.reportCameraReadyIfReady(attempt);
      }).catch(error => {
        if (attempt !== this.startAttempt) throw error;
        this.stopTracking();
        this.reportError(`No se pudo cargar el detector de movimientos. Revisa la conexión: ${error}`);
        throw error;
      });

      this.detectorTimeout = setTimeout(() => {
        if (attempt !== this.startAttempt || this.firstFrameProcessed) return;
        this.stopTracking();
        this.reportError('No se pudo iniciar el modelo de movimientos. Revisa tu conexión a internet (MediaPipe se carga en línea) e inténtalo de nuevo.');
      }, 25000);

      videoElement.muted = true;
      videoElement.autoplay = true;
      videoElement.setAttribute('playsinline', '');
      const cameraReady = navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: 'user',
          width: {ideal: 640},
          height: {ideal: 480}
        }
      }).then(async stream => {
        if (attempt !== this.startAttempt) {
          stream.getTracks().forEach(track => track.stop());
          return;
        }
        this.mediaStream = stream;
        videoElement.srcObject = stream;
        await videoElement.play();
        if (attempt !== this.startAttempt) return;
        this.cameraStreamReady = true;
        clearTimeout(this.startTimeout);
        this.startTimeout = null;
        this.reportHandStatus('left', this.detectorReady ? 'Buscando' : 'Cargando detector');
        this.reportHandStatus('right', this.detectorReady ? 'Buscando' : 'Cargando detector');
        this.reportCameraReadyIfReady(attempt);
      }).catch(error => {
        if (attempt !== this.startAttempt) throw error;
        this.stopTracking();
        this.reportError(this.cameraErrorMessage(error));
        throw error;
      });

      Promise.all([initializeDetector, cameraReady]).catch(error => {
        console.warn('Inicialización de cámara/detector:', error);
      });
    } catch (error) {
      this.stopTracking();
      this.reportError(`No se pudo iniciar la detección: ${error}`);
    }
  },

  cameraErrorMessage: function(error) {
    switch (error && error.name) {
      case 'NotAllowedError':
      case 'PermissionDeniedError':
        return 'Permiso de cámara denegado. Permite la cámara para este sitio desde el navegador e inténtalo de nuevo.';
      case 'NotFoundError':
        return 'No se encontró una cámara disponible en este dispositivo.';
      case 'NotReadableError':
        return 'La cámara está ocupada por otra aplicación. Ciérrala e inténtalo de nuevo.';
      case 'OverconstrainedError':
        return 'La cámara no admite la configuración solicitada.';
      default:
        return `No se pudo activar la cámara: ${error && error.message ? error.message : error}`;
    }
  },

  reportCameraReadyIfReady: function(attempt) {
    if (
      attempt !== this.startAttempt ||
      !this.cameraStreamReady ||
      !this.detectorReady ||
      !this.firstFrameProcessed ||
      this.reportedReady
    ) {
      return;
    }
    this.reportedReady = true;
    if (window.onWebPoseCameraReady) window.onWebPoseCameraReady();
  },

  scheduleFrame: function(videoElement, attempt) {
    if (this.frameRequest != null || attempt !== this.startAttempt) return;
    this.frameRequest = requestAnimationFrame(async () => {
      this.frameRequest = null;
      if (
        attempt !== this.startAttempt ||
        !this.pose ||
        !this.detectorReady ||
        videoElement.readyState < HTMLMediaElement.HAVE_CURRENT_DATA ||
        this.processingFrame
      ) {
        this.scheduleFrame(videoElement, attempt);
        return;
      }

      this.processingFrame = true;
      try {
        await this.pose.send({image: videoElement});
      } catch (error) {
        console.warn('Error procesando imagen para detectar movimientos:', error);
      } finally {
        this.processingFrame = false;
        this.scheduleFrame(videoElement, attempt);
      }
    });
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
    if (this.detectorTimeout) {
      clearTimeout(this.detectorTimeout);
      this.detectorTimeout = null;
    }
    if (this.frameRequest != null) {
      cancelAnimationFrame(this.frameRequest);
      this.frameRequest = null;
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
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
