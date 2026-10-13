# mirror 🛌📽️

> **The Problem:** My HDMI cable is exactly 1.5 meters too short to reach my bed, and getting up to sit at my desk after 9 PM violates my personal code of ethics.
>
> **The Reasonable Solution:** Buy a longer HDMI cable on Amazon ($9.99).  
> **What I Did Instead:** Spent hours engineering a real-time WebRTC screen mirroring system so my Mac streams to my iPhone, which plugs into the projector right beside my pillows.

---

## Why does this exist?

Peak laziness breeds peak engineering.

1. I wanted to watch stuff on my projector while staying in bed.
2. My Mac was stranded on my desk.
3. My HDMI cable didn't stretch to the bed.
4. My phone was already in my hand, and the projector cable reached the nightstand.

Result: Mac captures display ➔ streams low-latency WebRTC over local Wi-Fi ➔ iPhone opens a simple browser tab ➔ iPhone HDMI adapter sends it straight to the projector ceiling/wall. Zero apps to install on iOS.

---

## How it works

- **macOS ScreenCaptureKit**: Captures the Mac display smoothly at 60 FPS.
- **Embedded WebRTC + WebSockets**: Streams direct peer-to-peer video locally with practically zero latency.
- **Browser-only Client**: Safari on iPhone opens the local URL, accepts the WebRTC stream, goes full screen, and feeds the projector.

---

## How to run

### 1. Start the streamer on your Mac

```bash
swift run
```

### 2. Connect from bed

1. Look at your terminal (or don't, if you can see it from the bed).
2. Scan the printed QR code with your iPhone camera, or open:
   ```text
   https://<your-mac-local-ip>:8443
   ```
3. Hit **Connect** & go full screen.
4. Plug iPhone into projector. Done.

---

## Requirements

- macOS 13.0+ (Ventura or newer)
- iPhone, iPad, or any device with a modern browser on the same Wi-Fi
- Zero desire to get out of bed
