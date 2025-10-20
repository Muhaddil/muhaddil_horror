class HorrorSystem {
  constructor() {
    this.inZone = false;
    this.currentIntensity = "low";
    this.audioManager = new window.AudioManager();
    this.sanity = 100;
    this.activeEffects = new Set();
    this.init();
  }

  init() {
    window.addEventListener("message", (event) => {
      const data = event.data;

      try {
        switch (data.type) {
          case "notification":
            this.showNotification(data);
            break;
          case "enterZone":
            this.enterZone(data);
            break;
          case "leaveZone":
            this.leaveZone();
            break;
          case "jumpscare":
            this.triggerJumpscare(data.jumpscareType);
            break;
          case "whisper":
            this.playWhisper(data.sound);
            break;
          case "distortion":
            this.applyDistortion(data.distortionType, data.duration);
            break;
          case "ghostAppearance":
            // this.showGhost(data.duration);
            break;
          case "environmental":
            this.environmentalEffect(data.effect);
            break;
          case "paranormal":
            this.paranormalEffect(data.effectType);
            break;
          case "updateSanity":
            this.updateSanity(data.sanity);
            break;
          case "playAmbient":
            this.audioManager.playAmbient(data.ambientType, 0.2);
            break;
          case "stopAmbient":
            this.audioManager.stopAmbient();
            break;
        }
      } catch (error) {
        console.error("Error procesando mensaje:", error);
      }
    });

    this.initSanityMeter();
  }

  showNotification(data) {
    const container = document.getElementById("notification-container");
    const notification = document.createElement("div");
    notification.className = `notification ${data.isLeaving ? "leaving" : ""} intensity-${data.intensity || "low"}`;

    const icon = data.isLeaving ? "✓" : "⚠️";

    notification.innerHTML = `
      <div class="notification-icon">${icon}</div>
      <div class="notification-content">
        <div class="notification-title">${data.zoneName || (data.isLeaving ? "Zona Segura" : "Advertencia")
      }</div>
        <div class="notification-message">${data.message}</div>
      </div>
    `;

    container.appendChild(notification);

    requestAnimationFrame(() => {
      notification.style.opacity = "1";
      notification.style.transform = "translateX(0)";
    });

    // if (!data.isLeaving) {
    //   this.audioManager.playSound("notification", 0.3, false, 1000);
    // }

    setTimeout(() => {
      notification.style.opacity = "0";
      notification.style.transform = "translateX(400px)";
      setTimeout(() => notification.remove(), 300);
    }, 5000);
  }

  enterZone(data) {
    this.inZone = true;
    this.currentIntensity = data.intensity;

    const indicator = document.getElementById("zone-indicator");
    indicator.classList.remove("hidden");
    indicator.querySelector(".zone-name").textContent = data.zone;
    indicator.querySelector(".zone-intensity").textContent = `Intensidad: ${this.getIntensityText(data.intensity)}`;

    const vignette = document.getElementById("vignette-effect");
    vignette.classList.add("active");
    vignette.dataset.intensity = data.intensity;

    document.body.className = `intensity-${data.intensity}`;

    setTimeout(() => {
      indicator.style.opacity = "0";
      setTimeout(() => indicator.classList.add("hidden"), 500);
    }, 4000);
  }

  leaveZone() {
    this.inZone = false;

    const vignette = document.getElementById("vignette-effect");
    vignette.classList.remove("active");

    document.body.className = "";

    this.activeEffects.clear();
    this.audioManager.stopAll();
  }

  getIntensityText(intensity) {
    const texts = {
      low: "Baja ⚠️",
      medium: "Media ⚠️⚠️",
      high: "Alta ⚠️⚠️⚠️"
    };
    return texts[intensity] || intensity;
  }

  async triggerJumpscare() {
    const overlay = document.getElementById("jumpscare-overlay");
    const image = document.getElementById("jumpscare-image");

    try {
      const res = await fetch("list.json");
      const images = await res.json();

      const randomImage = images[Math.floor(Math.random() * images.length)];
      image.src = randomImage;
      overlay.classList.remove("hidden");

      const screamSounds = Object.keys(SOUND_URLS).filter(key => /^scream\d+$/.test(key));
      const randomScream = screamSounds[Math.floor(Math.random() * screamSounds.length)];
      this.audioManager.playSound(randomScream, 0.9, false, 2000);

      const glitchOverlay = document.getElementById("jumpscare-glitch");
      glitchOverlay.style.opacity = "1";
      document.body.style.animation = "slowMotion 0.5s ease-out";

      setTimeout(() => {
        overlay.classList.add("hidden");
        glitchOverlay.style.opacity = "0";
        document.body.style.animation = "";
      }, 1000);

    } catch (err) {
      console.error("Error cargando jumpscares:", err);
    }
  }
  
  playWhisper(sound) {
    const whisperSounds = ["whisper1", "whisper2"];
    const randomWhisper = whisperSounds[Math.floor(Math.random() * whisperSounds.length)];

    this.audioManager.playSound(randomWhisper, 0.4, false, 10000);

    this.createWhisperEffect();
  }

  createWhisperEffect() {
    const effect = document.createElement("div");
    effect.className = "whisper-effect";
    effect.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: radial-gradient(circle, transparent 60%, rgba(0,0,0,0.3) 100%);
      pointer-events: none;
      z-index: 50;
      animation: whisperPulse 2s ease-out;
    `;

    document.body.appendChild(effect);
    setTimeout(() => effect.remove(), 2000);
  }

  applyDistortion(type, duration) {
    if (this.activeEffects.has(type)) return;
    this.activeEffects.add(type);

    switch (type) {
      case "static":
        this.applyStaticEffect(duration);
        break;
      case "chromatic":
        this.applyChromaticEffect(duration);
        break;
      case "blur":
        this.applyBlurEffect(duration);
        break;
      case "darkness":
        this.applyDarknessEffect(duration);
        break;
      case "blindness":
        this.applyBlindnessEffect();
        break;
      case "removeblindness":
        this.removeBlindnessEffect();
        break;
      default:
        this.activeEffects.delete(type);
    }
  }

  applyStaticEffect(duration) {
    const element = document.getElementById("static-effect");
    element.classList.remove("hidden");

    setTimeout(() => {
      element.classList.add("hidden");
      this.activeEffects.delete("static");
    }, duration);
  }

  applyChromaticEffect(duration) {
    const element = document.getElementById("chromatic-effect");
    element.classList.remove("hidden");

    setTimeout(() => {
      element.classList.add("hidden");
      this.activeEffects.delete("chromatic");
    }, duration);
  }

  applyBlurEffect(duration) {
    document.body.style.filter = "blur(5px)";
    setTimeout(() => {
      document.body.style.filter = "";
      this.activeEffects.delete("blur");
    }, duration);
  }

  applyDarknessEffect(duration) {
    document.body.style.filter = "brightness(0.2) contrast(1.3)";
    setTimeout(() => {
      document.body.style.filter = "";
      this.activeEffects.delete("darkness");
    }, duration);
  }

  applyBlindnessEffect() {
    const overlay = document.getElementById("blindness-overlay");
    overlay.classList.add("active");
    this.activeEffects.add("blindness");
  }

  removeBlindnessEffect() {
    const overlay = document.getElementById("blindness-overlay");
    overlay.classList.remove("active");
    this.activeEffects.delete("blindness");
  }

  showGhost(duration) {
    const ghostContainer = document.getElementById("ghost-container");
    const ghostFigure = ghostContainer.querySelector(".ghost-figure");

    ghostFigure.style.backgroundImage = "url('images/ghost-apparition.jpg')";

    ghostContainer.classList.remove("hidden");

    this.audioManager.playSound("ambient1", 0.5, false, duration);

    this.createFogEffect();

    setTimeout(() => {
      ghostContainer.classList.add("hidden");
    }, duration);
  }

  createFogEffect() {
    const fog = document.createElement("div");
    fog.className = "fog-effect";
    fog.style.cssText = `
      position: fixed;
      bottom: 0;
      left: 0;
      width: 100vw;
      height: 40vh;
      background: linear-gradient(to top, rgba(200,200,200,0.3), transparent);
      pointer-events: none;
      z-index: 499;
      animation: fogRise 8s ease-out;
    `;

    document.body.appendChild(fog);
    setTimeout(() => fog.remove(), 8000);
  }

  environmentalEffect(effect) {
    switch (effect) {
      case "fog":
        this.createPersistentFog();
        break;
      case "thunder":
        this.flashScreen();
        this.audioManager.playSound("thunder", 0.8, false, 2000);
        break;
      case "rain":
        this.audioManager.playAmbient("ambient1", 0.3);
        setTimeout(() => this.audioManager.stopAmbient(), 15000);
        break;
      case "footsteps":
        this.playFootstepsSequence();
        break;
      case "laugh":
        const laughSounds = ["laugh1", "laugh2"];
        const randomLaugh = laughSounds[Math.floor(Math.random() * laughSounds.length)];
        this.audioManager.playSound(randomLaugh, 0.6, false, 8000);
        break;
      case "heartbeat":
        this.playHeartbeatSequence();
        break;
      case "door":
        this.audioManager.playSound("door", 0.7, false, 3000);
        this.createDoorEffect();
        break;
    }
  }

  createPersistentFog() {
    document.body.style.filter = "blur(2px) brightness(0.7)";
    this.audioManager.playAmbient("ambient2", 0.25);

    setTimeout(() => {
      document.body.style.filter = "";
      this.audioManager.stopAmbient();
    }, 15000);
  }

  playFootstepsSequence() {
    let steps = 0;
    const maxSteps = Math.floor(Math.random() * 5) + 3;

    const stepInterval = setInterval(() => {
      this.audioManager.playSound("footsteps", 0.5 + Math.random() * 0.3, false, 800);
      steps++;

      if (steps >= maxSteps) {
        clearInterval(stepInterval);
      }
    }, 600);
  }

  playHeartbeatSequence() {
    let beats = 0;
    const maxBeats = 12;
    let beatInterval = 900;

    const heartbeatLoop = setInterval(() => {
      this.audioManager.playSound("heartbeat", 0.7, false, 500);
      beats++;

      beatInterval = Math.max(400, beatInterval - 40);

      if (beats >= maxBeats) {
        clearInterval(heartbeatLoop);
      }
    }, beatInterval);
  }

  createDoorEffect() {
    const doorFlash = document.createElement("div");
    doorFlash.style.cssText = `
      position: fixed;
      top: ${Math.random() * 40 + 30}vh;
      left: ${Math.random() * 60 + 20}vw;
      width: 2px;
      height: 30vh;
      background: rgba(255, 255, 255, 0.3);
      z-index: 300;
      animation: doorCreak 0.5s ease-out;
    `;

    document.body.appendChild(doorFlash);
    setTimeout(() => doorFlash.remove(), 500);
  }

  paranormalEffect(effectType) {
    switch (effectType) {
      case "floating_objects":
        this.createFloatingObjects();
        break;
      case "shadow_figures":
        this.createShadowFigures();
        break;
      case "bloody_messages":
        this.createBloodyMessage();
        break;
    }
  }

  createFloatingObjects() {
    const objects = ["📖", "🕯️", "🪑", "🖼️", "⚰️"];
    const numObjects = Math.floor(Math.random() * 3) + 2;

    for (let i = 0; i < numObjects; i++) {
      setTimeout(() => {
        const obj = document.createElement("div");
        obj.textContent = objects[Math.floor(Math.random() * objects.length)];
        obj.style.cssText = `
          position: fixed;
          left: ${Math.random() * 80 + 10}vw;
          bottom: ${Math.random() * 20 + 10}vh;
          font-size: 3rem;
          z-index: 400;
          animation: floatObject 4s ease-in-out;
          pointer-events: none;
        `;

        document.body.appendChild(obj);
        setTimeout(() => obj.remove(), 4000);
      }, i * 800);
    }
  }

  createShadowFigures() {
    const positions = ["left", "right"];
    const position = positions[Math.floor(Math.random() * positions.length)];

    const shadow = document.createElement("div");
    shadow.style.cssText = `
      position: fixed;
      ${position}: 0;
      bottom: 0;
      width: 150px;
      height: 300px;
      background: linear-gradient(to top, rgba(0,0,0,0.9), transparent);
      z-index: 350;
      animation: shadowFigureAppear 3s ease-out;
      clip-path: ellipse(40% 50% at 50% 80%);
    `;

    document.body.appendChild(shadow);

    this.audioManager.playSound("whisper1", 0.4, false, 3000);

    setTimeout(() => shadow.remove(), 3000);
  }

  createBloodyMessage() {
    const messages = [
      "HUYE...",
      "NO ESTÁS SOLO",
      "DETRÁS DE TI",
      "AYUDA",
      "VETE"
    ];

    const message = messages[Math.floor(Math.random() * messages.length)];

    const textElement = document.createElement("div");
    textElement.textContent = message;
    textElement.style.cssText = `
      position: fixed;
      top: 30%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-size: 4rem;
      font-weight: bold;
      color: #8b0000;
      text-shadow: 2px 2px 10px rgba(0,0,0,0.8);
      z-index: 500;
      animation: bloodyTextAppear 4s ease-out;
      font-family: 'Creepster', cursive;
      letter-spacing: 0.2em;
      opacity: 0;
    `;

    document.body.appendChild(textElement);

    setTimeout(() => {
      textElement.style.opacity = "0.9";
    }, 100);

    this.audioManager.playSound("scream2", 0.4, false, 2000);

    setTimeout(() => {
      textElement.style.opacity = "0";
      setTimeout(() => textElement.remove(), 1000);
    }, 3000);
  }

  flashScreen() {
    const flash = document.createElement("div");
    flash.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: white;
      z-index: 10000;
      animation: flashAnimation 0.2s ease-out;
      pointer-events: none;
    `;

    document.body.appendChild(flash);
    setTimeout(() => flash.remove(), 200);
  }

  initSanityMeter() {
    const sanityMeter = document.getElementById("sanity-meter");
    if (!sanityMeter) {
      const meter = document.createElement("div");
      meter.id = "sanity-meter";
      meter.className = "hidden";
      meter.innerHTML = `
        <div class="sanity-icon">🧠</div>
        <div class="sanity-bar">
          <div class="sanity-fill" id="sanity-fill"></div>
        </div>
        <div class="sanity-text" id="sanity-text">100%</div>
      `;
      document.getElementById("app").appendChild(meter);
    }
  }

  updateSanity(sanity) {
    this.sanity = Math.max(0, Math.min(100, sanity));

    const sanityFill = document.getElementById("sanity-fill");
    const sanityText = document.getElementById("sanity-text");
    const sanityMeter = document.getElementById("sanity-meter");

    if (sanityFill && sanityText) {
      sanityFill.style.width = `${this.sanity}%`;
      sanityText.textContent = `${Math.floor(this.sanity)}%`;

      if (this.sanity < 30) {
        sanityFill.style.background = "linear-gradient(90deg, #8b0000, #ff0000)";
        sanityMeter.classList.add("critical");
      } else if (this.sanity < 60) {
        sanityFill.style.background = "linear-gradient(90deg, #ff8800, #ffaa00)";
        sanityMeter.classList.remove("critical");
      } else {
        sanityFill.style.background = "linear-gradient(90deg, #00ff00, #44ff44)";
        sanityMeter.classList.remove("critical");
      }

      if (this.inZone && this.sanity < 100) {
        sanityMeter.classList.remove("hidden");
      } else if (!this.inZone || this.sanity >= 100) {
        sanityMeter.classList.add("hidden");
      }
    }
  }
}

const horrorSystem = new HorrorSystem();

document.addEventListener("contextmenu", (e) => e.preventDefault());
document.addEventListener("selectstart", (e) => e.preventDefault());

const styleSheet = document.createElement("style");
styleSheet.textContent = `
  @keyframes slowMotion {
    0% { filter: blur(0px); }
    50% { filter: blur(3px); }
    100% { filter: blur(0px); }
  }
  
  @keyframes whisperPulse {
    0%, 100% { opacity: 0; }
    50% { opacity: 1; }
  }
  
  @keyframes fogRise {
    from { transform: translateY(100%); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
  
  @keyframes floatObject {
    0% { transform: translateY(100vh); opacity: 0; }
    20% { opacity: 1; }
    80% { opacity: 1; }
    100% { transform: translateY(-50vh); opacity: 0; }
  }
  
  @keyframes shadowFigureAppear {
    0% { opacity: 0; transform: scaleY(0); }
    30% { opacity: 1; transform: scaleY(1); }
    70% { opacity: 1; transform: scaleY(1); }
    100% { opacity: 0; transform: scaleY(0); }
  }
  
  @keyframes bloodyTextAppear {
    0% { opacity: 0; transform: translate(-50%, -50%) scale(0.5); filter: blur(10px); }
    20% { opacity: 0.9; transform: translate(-50%, -50%) scale(1); filter: blur(0px); }
    80% { opacity: 0.9; transform: translate(-50%, -50%) scale(1); filter: blur(0px); }
    100% { opacity: 0; transform: translate(-50%, -50%) scale(1.2); filter: blur(5px); }
  }
  
  @keyframes doorCreak {
    0% { transform: scaleX(1); opacity: 0; }
    50% { transform: scaleX(3); opacity: 0.6; }
    100% { transform: scaleX(1); opacity: 0; }
  }
  
  @keyframes flashAnimation {
    from { opacity: 1; }
    to { opacity: 0; }
  }
`;
document.head.appendChild(styleSheet);