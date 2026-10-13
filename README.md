# mirror 🛌📽️

> **The Problem:** My HDMI cable is slightly too short to reach my bed, and walking over to sit at my desk after a long day violates my personal code of ethics. But I really wanted to watch movies on my projector from the comfort of my bed.
>
> **The Reasonable Solution:** Order a longer HDMI cable on Amazon for ₹499 and wait for delivery.  
> **What I Did Instead:** Spent hours engineering a real-time, zero-latency screen mirror over local Wi-Fi so my Mac streams to my iPhone, which connects directly to the projector on my nightstand.

---

## Why does this exist?

Peak laziness breeds peak engineering.

Here is the exact bedtime dilemma:
1. I have a projector setup near my bed, but the projector's HDMI cable only reaches my nightstand.
2. My Mac was plugged in at my desk across the room.
3. Walking across the cold floor every time I wanted to pause, change video, or just watch from bed was out of the question.
4. My iPhone was right next to me in bed, and could easily plug into the projector via an adapter.

So instead of spending ₹499 or getting out of bed, I wrote this:
**Mac screen** ➔ captured locally ➔ streamed over Wi-Fi via WebRTC ➔ opened instantly in iPhone Safari ➔ projected onto the wall/ceiling. Zero apps to install on iOS.

---

## How it works

- **macOS ScreenCaptureKit**: Captures the Mac display smoothly at 60 FPS.
- **Embedded WebRTC + WebSockets**: Streams direct peer-to-peer video locally with practically zero lag.
- **Browser-only Client**: Safari on iPhone opens the local URL, accepts the WebRTC stream, goes full screen, and feeds the projector.

---

## How to run

### 1. Start the streamer on your Mac

```bash
swift run
```

### 2. Connect from bed

1. Look at your terminal (or don't, if you can see it from bed).
2. Scan the printed QR code with your iPhone camera, or open:
   ```text
   https://<your-mac-local-ip>:8443
   ```
3. Hit **Connect** & go full screen.
4. Plug iPhone into the projector. Relax.

---

## Requirements

- macOS 13.0+ (Ventura or newer)
- iPhone / iPad / any device with a modern browser on the same Wi-Fi
- A projector plugged into your phone (or just your phone screen)
- Zero desire to get out of bed
