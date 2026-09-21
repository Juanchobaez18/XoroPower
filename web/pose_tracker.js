// MediaPipe Pose Tracker for Web
// This script runs in the browser and sends shake events to Flutter

window.webPoseTracker = {
  camera: null,
  pose: null,
  
  lastLeftWristY: 0,
  lastRightWristY: 0,
  lastTimestamp: 0,
  
  lastLeftShakeTime: 0,
  lastRightShakeTime: 0,
  
  shakeVelocityThreshold: 0.001, // Normalized pixels per ms (0.8 / 1000 approx for web)
  
  startTracking: function(videoElement) {
    if (!videoElement) return;
    
    // Initialize Pose Model
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
    
    // Initialize Camera
    this.camera = new Camera(videoElement, {
      onFrame: async () => {
        if (this.pose) {
          await this.pose.send({image: videoElement});
        }
      },
      width: 640,
      height: 480
    });
    
    this.camera.start();
  },
  
  stopTracking: function() {
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
      if (velocity > this.shakeVelocityThreshold && (currentTime - this.lastLeftShakeTime) > 300) {
        this.lastLeftShakeTime = currentTime;
        this.dispatchShakeEvent('left');
      }
      this.lastLeftWristY = leftWrist.y;
    }
    
    // Calculate Right Velocity
    if (rightWrist) {
      const velocity = (rightWrist.y - this.lastRightWristY) / dt;
      if (velocity > this.shakeVelocityThreshold && (currentTime - this.lastRightShakeTime) > 300) {
        this.lastRightShakeTime = currentTime;
        this.dispatchShakeEvent('right');
      }
      this.lastRightWristY = rightWrist.y;
    }
    
    this.lastTimestamp = currentTime;
  },
  
  dispatchShakeEvent: function(side) {
    if (window.onWebPoseShakeDetected) {
      window.onWebPoseShakeDetected(side);
    }
  }
};
