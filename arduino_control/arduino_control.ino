#include <WiFiS3.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <IRremote.h>
#include <Servo.h>
#include "ir_codes.h"  // ✅ 로컬 IR 코드 헤더 포함

const char* ssid = "_";
const char* password = "_";

const char* mqtt_server = "000.000.000.000";
const int mqtt_port = 1883;
const char* mqtt_topic = "smartHome/metadata";

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

const int IR_SEND_PIN = 3;
const int SERVO_PIN = 9;

Servo curtainServo;
StaticJsonDocument<16384> irCodesDoc;
int curtain_power = 0;

void setup_wifi() {
  WiFi.begin(ssid, password);
  Serial.print("WiFi 연결 중");
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startTime < 10000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi 연결 완료!");
  } else {
    Serial.println("\n❌ WiFi 연결 실패!");
  }
}

bool loadIRCodesFromMemory() {
  DeserializationError error = deserializeJson(irCodesDoc, raw_ir_code_json);
  if (error) {
    Serial.print("❌ 내부 JSON 파싱 실패: ");
    Serial.println(error.c_str());
    return false;
  }
  Serial.println("✅ 내부 저장된 IR 코드 로딩 완료");
  return true;
}

void openCurtain() {
  Serial.println("↪️ 커튼 열기 (0 → 90 → 180)");
  curtainServo.write(0);
  delay(1200);
  curtainServo.write(90);
  Serial.println("✅ 커튼 열림 완료");
}

void closeCurtain() {
  Serial.println("↩️ 커튼 닫기 (180 → 90 → 0)");
  curtainServo.write(180);
  delay(1200);
  curtainServo.write(90);
  Serial.println("✅ 커튼 닫힘 완료");
}

void callback(char* topic, byte* payload, unsigned int length) {
  StaticJsonDocument<1024> msgDoc;
  Serial.println("🔔 MQTT 메시지 수신됨!");

  char buffer[256];  // 수신 메시지 버퍼
  memcpy(buffer, payload, length);
  buffer[length] = '\0';  // null-termination

  Serial.println("📦 수신된 메시지: ");
  Serial.println(buffer);

  DeserializationError error = deserializeJson(msgDoc, buffer);
  if (error) {
    Serial.print("❌ JSON 파싱 실패: ");
    Serial.println(error.c_str());
    return;
  }

  String mode = msgDoc["mode"];
  String control = msgDoc["control"];

  // ✅ 커튼 모드 처리: IR 송신 없이 서보 제어만
  if (mode == "curtain" && control == "power") {
    if (!curtain_power) {
      openCurtain();
      curtain_power = 1;
    } else if (curtain_power) { 
      closeCurtain();
      curtain_power = 0;
    } else {
      Serial.println("⚠️ 알 수 없는 커튼 제어 명령");
    }
    return;
  }

  if (!irCodesDoc.containsKey(mode) || !irCodesDoc[mode].containsKey(control)) {
    Serial.println("❌ 해당 mode/control에 대한 IR 코드 없음");
    return;
  }

  JsonArray codeArray = irCodesDoc[mode][control]["code"].as<JsonArray>();
  if (codeArray.isNull() || codeArray.size() == 0) {
    Serial.println("❌ code 배열 비어 있음");
    return;
  }

  uint16_t raw[70];
  size_t size = codeArray.size();
  for (int i = 0; i < size; i++) {
    raw[i] = codeArray[i];
  }

  IrSender.sendRaw(raw, size, 38);  // 38kHz carrier
  Serial.println("✅ IR 송신 완료!");
}

void reconnect() {
  while (!mqttClient.connected()) {
    Serial.print("MQTT 브로커 연결 시도 중...");
    if (mqttClient.connect("ArduinoUnoClient")) {
      Serial.println("✅ MQTT 연결됨.");
      mqttClient.subscribe(mqtt_topic);
      Serial.println("MQTT topic 구독 완료: " + String(mqtt_topic));
    } else {
      Serial.print("❌ 연결 실패. 상태 코드: ");
      Serial.print(mqttClient.state());
      Serial.println(" / 5초 후 재시도");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(9600);
  IrSender.begin(IR_SEND_PIN);
  curtainServo.attach(SERVO_PIN);
  curtainServo.write(90);  // 초기 위치

  setup_wifi();

  if (!loadIRCodesFromMemory()) {
    Serial.println("❌ IR 코드 로딩 실패");
  }

  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(callback);
}

void loop() {
  if (!mqttClient.connected()) {
    reconnect();
  }
  mqttClient.loop();
}
