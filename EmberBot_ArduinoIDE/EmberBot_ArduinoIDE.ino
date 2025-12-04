// Main ESP32 Code -  EMBERBOT

// Load Wi-Fi library
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <Arduino.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <FastLED.h>

// Replace with your network credentials
const char* ssid = "Jonathan-ESP32";
const char* password = "EmberBot";

// Web Server Port Number to 80
//WiFiServer server(80);
//WiFiClient client;
WebServer server(80);

// Motor Variables
#define rightMotorpin 12  // pin 12 is connected to PWM1
#define rightDir 14       //pin 14 is connected to DIR1
#define leftMotorpin 32   //pin 32 is connected to PWM2
#define leftDir 25        //pin 25 is connected to DIR2
#define numLEDs 10        //how many LEDs are on the strip
#define outLEDs 5         //pin on ESP32
//int userRightMotor = 0;
//int userLeftMotor = 0;
CRGB leds[numLEDs];

// Servo Variables
Servo xaxis;
Servo yaxis;

const int xServoPin = 19;
const int yServoPin = 18;
const int pumpPin = 26;


// Variable to store the HTTP request & coordinates
String header;
int leftMotor, prevLeft = 0.0;
int rightMotor, prevRight = 0.0;
int nozzleX, prevX = 0.0;
int nozzleY, prevY = 0.0;
int tmp_request, current_request = 0.0;
bool LED, pump = false;

unsigned long lastPrint = 0;
unsigned long lastInputTime = 0;             // Track last JSON input time
const unsigned long inputTimeout = 1000;     // 1 second
unsigned long lastSysInfoPrint = 0;          // for periodic system info
const unsigned long sysInfoInterval = 2000;  // print every 2 seconds

// Variables for CPU usage estimation
static unsigned long prevIdleTime = 0;
static unsigned long prevTime = 0;

// Set your Static IP address
IPAddress local_IP(192, 168, 1, 184);  // Local IP
// Camera IP = 192.168.4.50
// Coordinate WebServer = 192.168.4.1/coords
IPAddress gateway(192, 168, 1, 1);  // Gateway IP
IPAddress subnet(255, 255, 255, 0);

// GPIO States & Assignments
String output26State = "off";
String output27State = "off";
const int output26 = 26;
const int output27 = 27;

// Declaration and initialization of the input pins
int analog_input = A0;   // Analog output of the sensor -  Connect to GPIO36 (Analog)
int digital_input = 23;  // Digital output of the sensor - Connect to GPIO18 (Digital)
int output_led = 18;     // LED Pinout


// ---- physical mapping ----
const float DIST_IN = 60.0f;                          // 5 ft = 60 inches
const float OFFSET_PER_UNIT = 4.5f;                   // inches per coordinate unit
const float DEG_PER_UNIT = 4.289153f;                 // atan(4.5/60) in degrees
const float US_PER_DEG = 1000.0f / 180.0f;            // ~5.56 µs per degree
const float US_PER_UNIT = DEG_PER_UNIT * US_PER_DEG;  // ≈23.83 µs per coordinate unit
const float Y_OFFSET_IN = 4.0f;                       // camera offset (inches)
const float OFFSET_ANGLE_DEG = atan(Y_OFFSET_IN / DIST_IN) * 180.0 / PI;
const float Y_OFFSET_US = OFFSET_ANGLE_DEG * US_PER_DEG;

const int MAX_UNITS = 20;    // ±20 coordinate range
const int CENTER_US = 1500;  // neutral (0,0) position pulse width

// ---- per-axis motion tuning ----
int BACKLASH_X_US = 3;
int BACKLASH_Y_US = 10;  // Y axis often needs more compensation (increase if undershoot on reverse, decrease if overshoot)
int SMOOTH_STEPS_X = 15;
int SMOOTH_STEPS_Y = 22;  // smoother for heavier Y
int STEP_DELAY_MS_X = 10;
int STEP_DELAY_MS_Y = 18;  // longer delay to settle under load

// ---- calibration scaling ----
float SCALE_X = 1.0f;
float SCALE_Y = 1.0f;
int OFFSET_X_US = 0;
int OFFSET_Y_US = 0;

// ---- position state ----
int currentX_us = CENTER_US;
int currentY_us = CENTER_US;
int last_dx = 0;
int last_dy = 0;

void motorControl(int rightSpeed, int leftSpeed) {
  bool directionRight = false;
  bool directionLeft = false;

  if (rightSpeed < 0) {
    rightSpeed *= -1;
    directionRight = true;
  }
  if (leftSpeed < 0) {
    leftSpeed *= -1;
    directionLeft = true;
  }

  digitalWrite(rightDir, directionRight);
  digitalWrite(leftDir, directionLeft);
  ledcWrite(rightMotorpin, rightSpeed);
  ledcWrite(leftMotorpin, leftSpeed);

  //Serial.printf("Checker: rightSpeed = %d, leftSpeed = %d \n", rightSpeed, leftSpeed);
}


// --- Enhanced smooth servo move with per-axis compensation ---
void moveServoSmooth(int targetX_us_in, int targetY_us_in) {
  // apply per-axis scale & offset
  int targetX_us = constrain((int)round(CENTER_US + (targetX_us_in - CENTER_US) * SCALE_X) + OFFSET_X_US, 1000, 2000);
  int targetY_us = constrain((int)round(CENTER_US + (targetY_us_in - CENTER_US) * SCALE_Y) + OFFSET_Y_US, 1000, 2000);

  int dx = targetX_us - currentX_us;
  int dy = targetY_us - currentY_us;

  // detect reversal direction for overshoot compensation
  bool x_reversed = (dx != 0 && ((dx > 0 && last_dx < 0) || (dx < 0 && last_dx > 0)));
  bool y_reversed = (dy != 0 && ((dy > 0 && last_dy < 0) || (dy < 0 && last_dy > 0)));

  int adjustedX = targetX_us;
  int adjustedY = targetY_us;
  if (x_reversed) adjustedX += (dx > 0 ? BACKLASH_X_US : -BACKLASH_X_US);
  if (y_reversed) adjustedY += (dy > 0 ? BACKLASH_Y_US : -BACKLASH_Y_US);

  int steps = max(SMOOTH_STEPS_X, SMOOTH_STEPS_Y);
  for (int i = 1; i <= steps; i++) {
    int stepX = currentX_us + (adjustedX - currentX_us) * min(i, SMOOTH_STEPS_X) / SMOOTH_STEPS_X;
    int stepY = currentY_us + (adjustedY - currentY_us) * min(i, SMOOTH_STEPS_Y) / SMOOTH_STEPS_Y;

  xaxis.writeMicroseconds(stepX);
  yaxis.writeMicroseconds(stepY);
  //delay(max(STEP_DELAY_MS_X, STEP_DELAY_MS_Y));
  }

  // Settle back to true final target
  xaxis.writeMicroseconds(targetX_us);
  yaxis.writeMicroseconds(targetY_us);
  delay(60);  // small settle delay

  last_dx = dx;
  last_dy = dy;
  currentX_us = targetX_us;
  currentY_us = targetY_us;
}



// Function to clear any queued client data
void clearClientBuffer(WiFiClient& client) {
  while (client.available()) client.read();
}


void handlePostCoords() {
  // Flush any extra pending data from the client
  WiFiClient client = server.client();
  //while (client.available()) client.read(); // discard unread data
  //delay(2); // Small delay helps stabilize

  // Check if we received JSON
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"Missing JSON body\"}");
    return;
  }

  String json = server.arg("plain");
  // Remove stray NULLs or garbage characters
  json.trim();
  json.replace("\0", "");

  // Keep only the most recent JSON
  int lastBrace = json.lastIndexOf('{');
  if (lastBrace > 0) json = json.substring(lastBrace);

  // Validate JSON structure
  if (!json.startsWith("{") || !json.endsWith("}")) {
    Serial.println("[WARN] Ignored malformed JSON packet.");
    server.send(400, "application/json", "{\"error\":\"Corrupted packet ignored\"}");
    // Flush any junk leftover
    while (client.available()) client.read();
    return;
  }

  //Serial.println("Received JSON: " + json);

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, json);

  if (error) {
    Serial.println("JSON parse failed!");
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
    // Flush leftover data
    while (client.available()) client.read();
    return;
  }

  current_request = round(doc["request_number"].as<float>());

  if (current_request > tmp_request) {
    leftMotor = round(doc["left_position"].as<float>());
    rightMotor = round(doc["right_position"].as<float>());
    nozzleX = round(doc["mid_x"].as<float>());
    nozzleY = round(doc["mid_y"].as<float>());
    LED = doc["LED_Control"].as<bool>();
    pump = doc["pump"].as<bool>();
    lastInputTime = millis();

    Serial.printf("Tag = %d, Parsed coords: leftMotor=%d, rightMotor=%d, NozzleX=%d, NozzleY=%d, Pump=%d, LED=%d\n", current_request, leftMotor, rightMotor, nozzleX, nozzleY, pump, LED);
    server.send(200, "application/json", "{\"status\":\"ok\"}");
    tmp_request = current_request;
  } else {
    // Ignore duplicate or old requests
    server.send(200, "application/json", "{\"status\":\"ignored\"}");
  }

  while (client.available()) client.read();
}


void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>html{font-family:Helvetica;text-align:center;} .button{background-color:#4CAF50;border:none;color:white;padding:16px 40px;font-size:30px;margin:2px;cursor:pointer;} .button2{background-color:#555;}</style>";
  html += "</head><body><h1>ESP32 Web Server</h1>";

  // Form for manual coordinate input
  html += "<form action='/coords' method='get'>";
  html += "X: <input type='number' name='x'><br><br>";
  html += "Y: <input type='number' name='y'><br><br>";
  html += "<input type='submit' value='Send'>";
  html += "</form>";

  // Show last received coordinates
  html += "<p>Last received: X=" + String(nozzleX, 2) + " Y=" + String(nozzleY, 2) + "</p>";

  // GPIO 26 control
  html += "<p>GPIO 26 - State " + output26State + "</p>";
  html += "<p><a href='/26/" + String(output26State == "off" ? "on" : "off") + "'>";
  html += String("<button class='button'>") + (output26State == "off" ? "ON" : "OFF") + "</button></a></p>";

  // GPIO 27 control
  html += "<p>GPIO 27 - State " + output27State + "</p>";
  html += "<p><a href='/27/" + String(output27State == "off" ? "on" : "off") + "'>";
  html += String("<button class='button'>") + (output27State == "off" ? "ON" : "OFF") + "</button></a></p>";

  html += "</body></html>";

  server.send(200, "text/html", html);
}

// Functions to handle GPIO control
void handleGPIO26() {
  if (server.arg("action") == "on") {
    digitalWrite(output26, HIGH);
    output26State = "on";
  } else {
    digitalWrite(output26, LOW);
    output26State = "off";
  }
  server.sendHeader("Location", "/");
  server.send(303);  // Redirect to root
}

void handleGPIO27() {
  if (server.arg("action") == "on") {
    digitalWrite(output27, HIGH);
    output27State = "on";
  } else {
    digitalWrite(output27, LOW);
    output27State = "off";
  }
  server.sendHeader("Location", "/");
  server.send(303);  // Redirect to root
}

void setup() {
  Serial.begin(115200);

  // put your LED setup code here, to run once:
  FastLED.addLeds<WS2812, outLEDs, GRB>(leds, numLEDs);

  // Motors
  ledcAttach(rightMotorpin, 5000, 8);
  ledcAttach(leftMotorpin, 5000, 8);

  pinMode(rightDir, OUTPUT);
  pinMode(leftDir, OUTPUT);

  ledcWrite(rightMotorpin, 0);
  ledcWrite(leftMotorpin, 0);


  // Initialize the output variables as outputs
  /*pinMode(output26, OUTPUT);
  pinMode(output27, OUTPUT);
  // Set outputs to 0
  digitalWrite(output26, LOW);
  digitalWrite(output27, LOW);
  */
  // Connect to Wi-Fi network with SSID and password
  Serial.println("Setting AP (Access Point)…");
  // Can Remove Password Parameter if Desired
  WiFi.softAP(ssid, password);

  IPAddress IP = WiFi.softAPIP();
  Serial.print("ESP32 IP address: ");
  Serial.println(IP);

  // Define server routes
  //server.on("/", handleRoot);
  server.on("/coords", HTTP_POST, handlePostCoords);

  //Additional Pinout On/Off
  /*
  server.on("/26/on", []() {
    digitalWrite(output26, HIGH);
    output26State = "on";
    server.sendHeader("Location", "/");
    server.send(303);
  });
  server.on("/26/off", []() {
    digitalWrite(output26, LOW);
    output26State = "off";
    server.sendHeader("Location", "/");
    server.send(303);
  });
  server.on("/27/on", []() {
    digitalWrite(output27, HIGH);
    output27State = "on";
    server.sendHeader("Location", "/");
    server.send(303);
  });
  server.on("/27/off", []() {
    digitalWrite(output27, LOW);
    output27State = "off";
    server.sendHeader("Location", "/");
    server.send(303);
  });
  */

  server.begin();

  // Flame Sensor
  pinMode(analog_input, INPUT);
  pinMode(digital_input, INPUT);
  pinMode(output_led, OUTPUT);
  pinMode(pumpPin, OUTPUT);
  Serial.begin(115200);  // Serial output with 115200 Baus

  ESP32PWM::allocateTimer(3);
  ESP32PWM::allocateTimer(4);
  xaxis.setPeriodHertz(50);
  yaxis.setPeriodHertz(50);
  xaxis.attach(xServoPin, 1000, 2000);
  yaxis.attach(yServoPin, 1000, 2000);

  xaxis.writeMicroseconds(CENTER_US);
  yaxis.writeMicroseconds(CENTER_US);

  // Initialize timing variables
  //prevIdleTime = xTaskGetIdleRunTimeCounter();
  //prevTime = millis();
}

void loop() {
  server.handleClient();
  motorControl(rightMotor, leftMotor);

  
  // Compute microsecond targets
  float x_us_f = CENTER_US - (nozzleX * US_PER_UNIT);                      // inverted X axis
  float y_us_f = CENTER_US + (nozzleY * US_PER_UNIT) - (2 * Y_OFFSET_US);  // standard Y axis
  int x_us = constrain((int)round(x_us_f), 1000, 2000);
  int y_us = constrain((int)round(y_us_f), 1000, 2000);
  moveServoSmooth(x_us, y_us);

  bool TargetAnalysisText = false;
  if (TargetAnalysisText){
    Serial.printf("Target: (%d,%d)  =>  X=%dµs  Y=%dµs\n", nozzleX, nozzleY, x_us, y_us);
  }

  
  static bool lastLED = false;
  if (LED != lastLED) {
      lastLED = LED;
      fill_solid(leds, numLEDs, LED ? CRGB::White : CRGB::Black);
      FastLED.show();
  }


  if (pump) {
    digitalWrite(pumpPin, HIGH);
  } else {
    digitalWrite(pumpPin, LOW);
  }

  bool temp_text = false;
  if (temp_text) {
    Serial.println("KY-026 Flame Detection:");
    // Run the flame sensor check all the time
    float analog_value;
    int digital_value;

    analog_value = analogRead(analog_input) * (5.0 / 1023.0);
    digital_value = digitalRead(digital_input);

    Serial.print("Analog Voltage Value: ");
    Serial.print(analog_value, 4);

    if (analog_value <= 14)
      digitalWrite(output_led, HIGH);
    else
      digitalWrite(output_led, LOW);

    Serial.print(" V; \t Digital Threshold Value: ");
    bool digital_display = false;
    if (digital_value == 1) {
      Serial.println("Flame Detected");
      if (digital_display)
        digitalWrite(output_led, HIGH);
    } else {
      Serial.println("Flame Not Detected");
      if (digital_display)
        digitalWrite(output_led, LOW);
    }
    Serial.println("----------------------------------------------------------------");
    //delay(1000);  // Optional delay to avoid spamming Serial Monitor
  }

  bool resetsec = false;
  if (resetsec) {
    // Reset values if no new input for 1 second
    if (millis() - lastInputTime > inputTimeout) {
      if (leftMotor != 0 || rightMotor != 0 || nozzleX != 0 || nozzleY != 0) {
        leftMotor = 0;
        rightMotor = 0;
        nozzleX = 0;
        nozzleY = 0;
        Serial.println("No input received for 1 second. Resetting all values to 0.");
      }
    }
  }

  // Print coordinates every 1000ms
  bool displaycurrentcords = false;
  if (millis() - lastPrint >= 1000 && displaycurrentcords) {
    lastPrint = millis();
    Serial.printf("Current coords: leftMotor=%d, rightMotor = %d, NozzleX=%d, NozzleY=%d\n", leftMotor, rightMotor, nozzleX, nozzleY);
  }

  bool resourcemonitor = false;
  unsigned long currentTime = millis();
  // --- System resource monitor ---
  if (currentTime - lastSysInfoPrint >= sysInfoInterval && resourcemonitor) {
    lastSysInfoPrint = currentTime;

    // --- RAM info ---
    uint32_t freeHeap = ESP.getFreeHeap();
    uint32_t minHeap = ESP.getMinFreeHeap();
    uint32_t maxAllocHeap = ESP.getMaxAllocHeap();

    // --- CPU info ---
    uint32_t cpuFreq = getCpuFrequencyMhz();  // MHz

    /*
    // --- Estimate CPU usage --- 
    unsigned long idleTime = xTaskGetIdleRunTimeCounter();
    unsigned long idleDelta = idleTime - prevIdleTime;
    unsigned long timeDelta = currentTime - prevTime;

    // Approximate CPU usage (%) over last interval
    float cpuUsage = 100.0 * (1.0 - ((float)idleDelta / (float)(timeDelta * (cpuFreq / 1000))));

    prevIdleTime = idleTime;
    prevTime = currentTime;
    */
    // --- Print info ---
    Serial.println("========== System Info ==========");
    Serial.printf("CPU Frequency: %d MHz\n", cpuFreq);
    Serial.printf("Available RAM: %d bytes\n", freeHeap);
    Serial.printf("Lowest Free RAM since Boot: %d bytes\n", minHeap);
    Serial.printf("Largest Allocatable Block: %d bytes\n", maxAllocHeap);
    Serial.printf("Flash size: %u bytes\n", ESP.getFlashChipSize());
    //Serial.printf("CPU Usage: %.2f%%\n", cpuUsage);
    Serial.println("=================================\n");
  }
}
