window.xoroAudioFeedback = (() => {
  let audioContext;

  function getAudioContext() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) throw new Error('Este navegador no admite audio web.');
    audioContext ??= new AudioContext();
    return audioContext;
  }

  function resume(context) {
    if (context.state === 'suspended') {
      context.resume().catch(error => {
        console.warn('No se pudo activar el audio local:', error);
      });
    }
  }

  return {
    initialize() {
      const context = getAudioContext();
      resume(context);
    },

    play(kind) {
      const context = getAudioContext();
      resume(context);

      const tones = {
        metronome: [1150, 0.045],
        hit: [880, 0.11],
        miss: [180, 0.14]
      };
      const [frequency, duration] = tones[kind] || tones.metronome;
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      const now = context.currentTime;

      oscillator.type = kind === 'miss' ? 'triangle' : 'sine';
      oscillator.frequency.setValueAtTime(frequency, now);
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.exponentialRampToValueAtTime(0.18, now + 0.008);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
      oscillator.connect(gain).connect(context.destination);
      oscillator.start(now);
      oscillator.stop(now + duration);
    }
  };
})();
