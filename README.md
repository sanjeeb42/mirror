# mirror 🛋️📽️

> My HDMI cable is too short to reach the bed, and I'm too lazy to walk to my desk. So here we are.

Stream your Mac screen directly to your iPhone over local Wi-Fi with ultra-low latency via WebRTC. Plug your phone into your projector, stay in bed, and enjoy the show.

## What this does

1. Captures Mac screen in real time using macOS ScreenCaptureKit.
2. Streams it over local Wi-Fi via WebRTC + WebSockets.
3. Open the local web URL on your iPhone (or iPad/projector adapter) — zero apps needed on the phone.

## Requirements

- macOS 13.0+ (Ventura or later)
- Swift 5.9+
- iPhone / browser on the same Wi-Fi network

## Run

```bash
swift run
```

Then scan the QR code printed in the terminal or open the local URL on your iPhone browser.
