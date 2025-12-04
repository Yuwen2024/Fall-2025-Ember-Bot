
## 🎯 Project Overview

- **ESP32-CAM module** — runs firmware in `EmberBotCam/`, serves video stream over HTTP, enabling remote camera monitoring.  
- **Sensor-node / Controller** — firmware under `EmberBot_ArduinoIDE/`, interfaces with controls (motors,pump, etc.), and gathers data.  
- **Mobile / Client app** — front-end to interact with bot, and view camera feed (code under `Mobile App Code/`).  
- **Documentation & Report** — final report provides overview of design, architecture, results, and any analysis.

## 🛠️ Getting Started (Development / Deployment)

### Prerequisites  
- Arduino IDE or PlatformIO (with ESP32 support)  
- ESP32 and ESP32-CAM hardware  
- USB or serial connection for flashing  
- Mobile Development Environment — Flutter  

### Flashing Firmware  

**For ESP32:**  
1. Open the project in `EmberBot_ArduinoIDE/`.  
2. Select appropriate ESP32 board.  
3. Upload the firmware to the sensor/controller module. 

**For ESP32-CAM (camera):**  
1. Open the project in `EmberBotCam/` via Arduino IDE or PlatformIO.  
2. Select the correct board: “AI Thinker ESP32-CAM”.  
3. Upload the code.  
4. Ensure correct pin configuration in `camera_pins.h`.  
5. Access the camera’s HTTP streaming via its IP — e.g. `http://<esp32-cam-ip>/stream`  

## ✅ What This Repo Contains (and What to Expect)  

- Fully working camera streaming code (with HTTP server) in `EmberBotCam/`  
- Controller/sensor firmware in `EmberBot_ArduinoIDE/`  
- Mobile-app code (if implemented) in `Mobile App Code/`  
- Final project documentation summarizing design, results, and usage  
- This README for overview + setup instructions  

## 💡 Notes & Recommendations  

- For best results with ESP32-CAM, ensure correct camera model and pin mapping (`camera_pins.h`)  
- On Windows systems: beware of line-ending conversions (LF vs CRLF) — consider adding `.gitattributes` if collaborating.  
- When pushing code: double-check that all files are committed, especially `.ino`, `.cpp`, `.h`, and config/data files.  
- If you add new modules (e.g. sensor, mobile, camera), update this README to reflect their location and how to build/use them  

## 👥 Contributors  

- [Yuwen2024](https://github.com/Yuwen2024)  (Yuwen Zheng)
- [Jjchen09](https://github.com/Jjchen09) (Jonathan Chen)  
- [nramirez2903](https://github.com/nramirez2903)  (Nancy Ramirez Castillo)
- (Kevin Rivera)
