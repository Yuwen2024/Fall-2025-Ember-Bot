// ESP32-CAM & Internal LED Flash

#include "esp_camera.h"
#include <WiFi.h>

#define CAMERA_MODEL_AI_THINKER // Has PSRAM
#include "camera_pins.h"
int flashPin = 4;

// WiFi Credentials - ESP32 WiFi-Acesss Point
const char *ssid = "Jonathan-ESP32";
const char *password = "EmberBot";

// Hotspot Testing
//const char *ssid = "JonathanChen";
//const char *password = "Souichri";

// Static IP configuration
IPAddress local_IP(192, 168, 4, 50);   // Local IP
IPAddress gateway(192, 168, 4, 1);      // Gateway IP
IPAddress subnet(255, 255, 255, 0);

void startCameraServer();
void setupLedFlash(int pin);

void setup() {
  Serial.begin(115200); // Baud Value
  Serial.setDebugOutput(true);
  Serial.println();

  // Built-In LED
  //pinMode(flashPin, OUTPUT);
  //digitalWrite(flashPin, LOW); // Ensure flash is off initially

  // 🔧 Configure Static IP BEFORE WiFi.begin()
  if (!WiFi.config(local_IP, gateway, subnet)) {
    Serial.println("⚠️ Failed to configure Static IP");
  }
  
  // Pinout
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.frame_size = FRAMESIZE_UXGA;
  config.pixel_format = PIXFORMAT_JPEG;  // Streaming Format
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  // QVGA Set Data
  //config.frame_size = FRAMESIZE_QVGA;   // 320x240 

  // if PSRAM IC present, init with UXGA resolution and higher JPEG quality
  //                      for larger pre-allocated frame buffer.
  if (config.pixel_format == PIXFORMAT_JPEG) {
    if (psramFound()) {
      config.jpeg_quality = 10;
      config.fb_count = 2;
      config.grab_mode = CAMERA_GRAB_LATEST;
    } else {
      // Limit Frame Size when no PSRAM
      config.frame_size = FRAMESIZE_SVGA;
      config.fb_location = CAMERA_FB_IN_DRAM;
    }

// Other ESP32 Cam Models
#if CONFIG_IDF_TARGET_ESP32S3 
    config.fb_count = 2;
#endif
  }

#if defined(CAMERA_MODEL_ESP_EYE)
  pinMode(13, INPUT_PULLUP);
  pinMode(14, INPUT_PULLUP);
#endif

  // CAM Initialization
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
      Serial.printf("Camera Initialization failed with error 0x%x\n", err);
  } else {
      Serial.println("Camera Initialized Successfully!");
  }


  sensor_t *s = esp_camera_sensor_get();
  // initial sensors are flipped vertically and colors are a bit saturated
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);        // flip it back
    s->set_brightness(s, 1);   // up the brightness just a bit
    s->set_saturation(s, -2);  // lower the saturation
  }
  // drop down frame size for higher initial frame rate
  if (config.pixel_format == PIXFORMAT_JPEG) {
    s->set_framesize(s, FRAMESIZE_QVGA);
  }

#if defined(CAMERA_MODEL_M5STACK_WIDE) || defined(CAMERA_MODEL_M5STACK_ESP32CAM)
  s->set_vflip(s, 1);
  s->set_hmirror(s, 1);
#endif

// If you want to changes to ESP32-S3
#if defined(CAMERA_MODEL_ESP32S3_EYE)
  s->set_vflip(s, 1);
#endif

// Setup LED FLash if LED pin is defined in camera_pins.h
#if defined(LED_GPIO_NUM)
  setupLedFlash(LED_GPIO_NUM);
#endif

// Begin WiFi Connection
  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi connected");

  startCameraServer();

  Serial.print("Camera Ready! Use 'http://");
  Serial.print(WiFi.localIP());
  Serial.println("' to connect");

}


void loop() {
  // Do nothing. Everything is done in another task by the web server
  //digitalWrite(flashPin, HIGH); // Built-In LED on Camera
  //delay(1000);
  //digitalWrite(flashPin, LOW); // Built-In LED on Camera
}
