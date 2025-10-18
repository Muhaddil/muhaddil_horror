
// URLs sonidos - Estas son gratuitas
const SOUND_URLS = {
  scream1: "https://assets.mixkit.co/active_storage/sfx/2482/2482-preview.mp3",
  scream2: "https://assets.mixkit.co/active_storage/sfx/1830/1830-preview.mp3",
  scream3: "https://assets.mixkit.co/active_storage/sfx/2487/2487-preview.mp3",

  whisper1: "https://assets.mixkit.co/active_storage/sfx/2483/2483-preview.mp3",
  whisper2: "https://assets.mixkit.co/active_storage/sfx/2484/2484-preview.mp3",

  ambient1: "https://assets.mixkit.co/active_storage/sfx/2485/2485-preview.mp3",
  ambient2: "https://assets.mixkit.co/active_storage/sfx/2486/2486-preview.mp3",

  cemetery: "https://assets.mixkit.co/active_storage/sfx/2485/2485-preview.mp3",
  forest: "https://assets.mixkit.co/active_storage/sfx/2486/2486-preview.mp3",
  house: "https://assets.mixkit.co/active_storage/sfx/2485/2485-preview.mp3",
  tunnel: "https://assets.mixkit.co/active_storage/sfx/2486/2486-preview.mp3",

  laugh1: "https://assets.mixkit.co/active_storage/sfx/2265/2265-preview.mp3",
  laugh2: "https://assets.mixkit.co/active_storage/sfx/1832/1832-preview.mp3",

  footsteps: "https://assets.mixkit.co/active_storage/sfx/2489/2489-preview.mp3",
  heartbeat: "https://assets.mixkit.co/active_storage/sfx/2490/2490-preview.mp3",
  door: "https://assets.mixkit.co/active_storage/sfx/2491/2491-preview.mp3",
  thunder: "https://assets.mixkit.co/active_storage/sfx/1704/1704-preview.mp3",
  
  notification: "https://assets.mixkit.co/active_storage/sfx/1646/1646-preview.mp3",
  
  breathing: "https://assets.mixkit.co/active_storage/sfx/2483/2483-preview.mp3",
};

class AudioManager {
  constructor() {
    this.sounds = {};
    this.currentAmbient = null;
    this.preloadedSounds = new Set();
    this.maxVolume = 1.0;
    
    this.preloadCriticalSounds();
  }

  preloadCriticalSounds() {
    const criticalSounds = ['scream1', 'scream2', 'scream3', 'ambient1', 'ambient2'];
    criticalSounds.forEach(soundName => {
      if (SOUND_URLS[soundName]) {
        this.preloadSound(soundName, SOUND_URLS[soundName]);
      }
    });
  }

  preloadSound(name, url) {
    if (!this.sounds[name] && url) {
      try {
        const audio = new Audio(url);
        audio.preload = "auto";
        audio.volume = 0;
        
        audio.load();
        
        this.sounds[name] = audio;
        this.preloadedSounds.add(name);
        
        if (window.DEBUG_MODE) {
          console.log(`✅ Sonido precargado: ${name}`);
        }
      } catch (error) {
        console.warn(`⚠️ Error precargando sonido ${name}:`, error);
      }
    }
  }

  playSound(name, volume = 1.0, loop = false, duration = null) {
    const url = SOUND_URLS[name];
    
    if (!url) {
      console.warn(`⚠️ Sonido "${name}" no encontrado en SOUND_URLS`);
      return null;
    }

    try {
      if (!this.sounds[name]) {
        this.preloadSound(name, url);
      }

      const sound = this.sounds[name].cloneNode();
      sound.volume = Math.min(volume * this.maxVolume, 1.0);
      sound.loop = loop;

      const playPromise = sound.play();
      
      if (playPromise !== undefined) {
        playPromise
          .then(() => {
            if (window.DEBUG_MODE) {
              console.log(`🔊 Reproduciendo: ${name}`);
            }
          })
          .catch((err) => {
            console.error(`❌ Error reproduciendo ${name}:`, err);
          });
      }

      if (duration && !loop) {
        setTimeout(() => {
          sound.pause();
          sound.currentTime = 0;
        }, duration);
      }

      return sound;
    } catch (error) {
      console.error(`❌ Error general reproduciendo ${name}:`, error);
      return null;
    }
  }

  playAmbient(name, volume = 0.3, duration = null) {
    this.stopAmbient();

    if (!SOUND_URLS[name]) {
      console.warn(`⚠️ Sonido ambiental "${name}" no encontrado`);
      return null;
    }

    this.currentAmbient = this.playSound(name, volume, true);

    if (duration) {
      setTimeout(() => {
        this.stopAmbient();
      }, duration);
    }

    return this.currentAmbient;
  }

  stopAmbient() {
    if (this.currentAmbient) {
      try {
        this.currentAmbient.pause();
        this.currentAmbient.currentTime = 0;
        this.currentAmbient = null;
      } catch (error) {
        console.warn("Error deteniendo ambiente:", error);
      }
    }
  }

  stopAll() {
    Object.values(this.sounds).forEach((sound) => {
      try {
        sound.pause();
        sound.currentTime = 0;
      } catch (error) {
        // Ignorar errores al detener
      }
    });
    
    this.stopAmbient();
  }

  setMasterVolume(volume) {
    this.maxVolume = Math.max(0, Math.min(1, volume));
  }

  fadeOut(sound, duration = 1000) {
    if (!sound) return;

    const startVolume = sound.volume;
    const fadeStep = startVolume / (duration / 50);
    
    const fadeInterval = setInterval(() => {
      if (sound.volume > fadeStep) {
        sound.volume -= fadeStep;
      } else {
        sound.volume = 0;
        sound.pause();
        clearInterval(fadeInterval);
      }
    }, 50);
  }

  fadeIn(sound, targetVolume = 1.0, duration = 1000) {
    if (!sound) return;

    sound.volume = 0;
    const fadeStep = targetVolume / (duration / 50);
    
    const fadeInterval = setInterval(() => {
      if (sound.volume < targetVolume - fadeStep) {
        sound.volume += fadeStep;
      } else {
        sound.volume = targetVolume;
        clearInterval(fadeInterval);
      }
    }, 50);
  }

  isSoundAvailable(name) {
    return SOUND_URLS.hasOwnProperty(name);
  }

  getAvailableSounds() {
    return Object.keys(SOUND_URLS);
  }
}

window.AudioManager = AudioManager;

if (window.DEBUG_MODE) {
  console.log("🎵 Audio Manager inicializado");
  console.log(`📊 Sonidos disponibles: ${Object.keys(SOUND_URLS).length}`);
  console.log("🔊 Lista de sonidos:", Object.keys(SOUND_URLS));
}