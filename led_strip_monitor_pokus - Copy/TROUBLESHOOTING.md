# Troubleshooting Guide

## Black Screen on Netflix / Disney+ / Prime Video
If your LEDs turn off or the screen capture shows black while watching streaming services, this is due to **DRM (Digital Rights Management)** protection. Browsers use hardware acceleration to encrypt the video path, preventing screen capture tools from seeing the content.

### Solution: Disable Hardware Acceleration
You need to disable "Hardware Acceleration" in your browser settings. This will force the browser to render video in a way that can be captured.

#### Google Chrome / generic Chromium (Brave, Vivaldi)
1.  Go to **Settings** (`chrome://settings`).
2.  Click on **System** in the left sidebar.
3.  Toggle **OFF** "Use graphics acceleration when available".
4.  **Relaunch** the browser.

#### Microsoft Edge
1.  Go to **Settings** (`edge://settings`).
2.  Click on **System and performance**.
3.  Toggle **OFF** "Use graphics acceleration when available".
4.  **Restart** Edge.

#### Firefox
1.  Go to **Settings**.
2.  Search for "Performance".
3.  Uncheck "Use recommended performance settings".
4.  Uncheck "Use hardware acceleration when available".
5.  Restart Firefox.

> **Note:** This might slightly increase CPU usage when watching 4K video, but it is necessary for AmbiLight to "see" the video.
