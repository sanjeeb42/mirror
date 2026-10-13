# mirror 🛌📽️

> **The Problem:** The projector is at my desk, and the HDMI cable is too short to reach my bed. Getting out of bed to sit at the desk after a long day is simply out of the question.
>
> **The Reasonable Solution:** Buy a super long, high-speed HDMI cable on Amazon for ₹3,000 and wait 2 days.  
> **What I Did Instead:** Left my phone at the desk plugged into the projector, stayed in bed with my Mac, and engineered a real-time WebRTC streamer to beam my Mac screen straight to the phone. Saved ₹3,000 and *wooh* — movie night from bed unlocked.

---

## Why does this exist?

Peak laziness breeds peak engineering.

Here is the exact setup:
1. The **projector is sitting at my desk**.
2. The **HDMI cable is way too short** to reach my bed.
3. I wanted to lie in bed with my Mac, browsing and controlling what to watch.
4. My phone can just sit at the desk, plugged into the projector.

So instead of blowing ₹3,000 on an absurdly long cable or dragging my blankets to the desk, I built this:

```text
[ Mac in Bed ] ──(Wi-Fi / WebRTC)──▶ [ iPhone at Desk ] ──(HDMI)──▶ [ Projector ]
```

Mac captures screen in real-time ➔ streams over local Wi-Fi with practically zero latency ➔ iPhone opens a simple URL in Safari and outputs to the projector. Zero iOS apps required.

---

## How it works

- **macOS ScreenCaptureKit**: Captures the Mac display smoothly at 60 FPS.
- **Embedded WebRTC + WebSockets**: Streams direct peer-to-peer video locally with practically zero lag.
- **Browser-only Client**: iPhone Safari connects over local Wi-Fi, enters fullscreen, and pushes the video output straight to the HDMI-connected projector.

---

## How to run

### 1. Start the streamer on your Mac (from bed)

```bash
swift run
```

### 2. Connect the phone (at desk)

1. Plug your phone into the projector's HDMI cable at your desk.
2. Open Safari on the phone and navigate to:
   ```text
   https://<your-mac-local-ip>:8443
   ```
   *(or scan the QR code printed in the terminal)*
3. Tap **Connect** & go fullscreen.
4. Jump back into bed with your Mac. Enjoy the big screen!

---

## Requirements

- macOS 13.0+ (Ventura or newer)
- iPhone / iPad / any device connected to the projector on the same Wi-Fi
- Zero desire to sit at your desk or spend ₹3,000 on cables
