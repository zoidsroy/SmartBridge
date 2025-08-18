# SmartBridge
스마트 가전이 아닌 기기까지 제어 가능한 AIoT 기반 만능 리모컨 시스템

<!-- 헤더: 움직이는 타이핑 배너 -->
<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=28&pause=1000&center=true&vCenter=true&width=750&lines=Hi+I'm+SmartBridge!;AIoT+기반+만능+리모컨+시스템" alt="Typing SVG" />
</p>


<!-- 제목 -->
<h1 align="center">✨ SmartBridge — AIoT 만능 리모컨 ✨</h1>

<p align="center">
  기존 가전을 교체하지 않고도 스마트홈 환경에 연결할 수 있는 <b>AIoT 기반 만능 리모컨 시스템</b>
</p>

---

## 📌 프로젝트 개요

SmartBridge는 기존 가전을 교체하지 않고도 스마트홈 환경에서 제어할 수 있도록 만든  
**AIoT 기반 만능 리모컨**입니다.  

- 🖐 **손 제스처 인식**과 🎤 **음성 인식**을 통해 입력  
- Arduino UNO R4 WiFi를 이용해 **적외선(IR) 신호 송신**  
- 구형 가전을 스마트홈 통합 시스템에 연결  

---

## 🎯 개발 배경

💡 최신 스마트홈 기기는 대부분 **Wi-Fi 또는 BLE** 기반이지만,  
여전히 많은 가전은 **IR 리모컨**을 사용합니다.  

- 구형 가전은 스마트홈 생태계에서 배제되는 경우 多  
- 고령자 및 디지털 취약 계층은 **앱 기반 제어 UI** 사용에 어려움 존재  

👉 **SmartBridge**는 **제스처/음성 중심 직관적 제어**를 목표로 합니다.

---

## 🚀 프로젝트 실행 방법

1. **가상환경 설치 및 활성화**
   ```bash
   python -m venv venv
   source venv/bin/activate   # (Mac/Linux)
   venv\Scripts\activate      # (Windows)

2. **라이브러리 설치**
   ```bash
   pip install -r requurements.txt


3. **Flask 서버 실행**
   ```bash
   python app.py

4. **ngrok 실행**
   ```bash
   ngrok http 5000

5. **colab 실행**

6. **.pkl, .pth 모델 파일을 test코드 레포지토링 위치**

7. **테스트 실행**
   ```bash
   python test.py

## 🔑 주요 기능

### 🖐 손 제스처 인식
- Mediapipe 기반 손 관절 추출  
- MLP+TCN 기반 제스처 분류  

### 🎤 음성 명령 인식
- Google STT 기반 STT (음성 → 텍스트)  
- Google TTS (텍스트 → 음성 응답)  

### 📡 가전 제어
- Arduino UNO R4 WiFi + IR LED  
- 360° 서보모터로 특정 가전 방향 송신  
- Firebase RTDB로 IR 코드 관리  

### 🌐 시스템 연동
- Flask 서버: 제스처/음성 처리  
- MQTT 통신: 서버 ↔ 아두이노  
- Flutter 앱: 대시보드 UI 제공  

## 🏗️ 시스템 아키텍처

    [사용자] → (제스처 / 음성 입력)
          ↓
    [Flask 서버] → MQTT → [Arduino UNO R4 WiFi] → IR LED → [가전제품]
          ↓
    [Firebase RTDB] ↔ [Flutter 앱]

## ✅ 기대 효과

-   구형 가전도 교체 없이 스마트홈에 연결 가능\
-   제스처/음성 제어로 누구나 직관적 사용 가능\
-   고령자·장애인 접근성 향상


## 📡 MQTT 기반 펌웨어 소개

본 프로젝트는 **Arduino UNO R4 WiFi 보드**를 기반으로,  
MQTT를 통한 스마트홈 기기 제어 및 **IR 송신**, **커튼 제어(서보모터)**를 수행하는 펌웨어입니다.  

---

## 📌 요구사항 (Requirements)

### 🛠️ 하드웨어
- Arduino UNO R4 WiFi 보드  
- IR LED 송신기 (**핀: D3**)  
- 360° 서보모터 (**핀: D9**)  
- MQTT Broker (예: Mosquitto, 라즈베리파이 또는 PC에서 실행)  
- Wi-Fi AP (SSID, Password 필요)  

### 📚 라이브러리  
*(Arduino IDE → 라이브러리 매니저에서 설치 가능)*  
- **WiFiS3**  
- **PubSubClient**  
- **ArduinoJson** (버전 6.x 이상 권장)  
- **IRremote** (버전 4.x 이상)  
- **Servo** (Arduino 내장)  

---

## ⚙️ 환경 설정 (Environment Setup)

### 1️⃣ Arduino IDE 설치
- Arduino IDE (**v2.x 권장**) 설치 후,  
  Arduino UNO R4 WiFi 보드 매니저 추가  

### 2️⃣ 라이브러리 설치
Arduino IDE → 상단 메뉴 → **스케치 → 라이브러리 포함하기 → 라이브러리 관리** → 아래 항목 설치
- WiFiS3  
- PubSubClient  
- ArduinoJson  
- IRremote  
- Servo (기본 제공)  

### 3️⃣ MQTT 브로커 설정
- 로컬 또는 원격 서버에 **MQTT 브로커 실행** (예: Mosquitto)  
- 코드 내 변수 수정  

### 4️⃣ Wi-Fi 접속 정보 수정
- 코드 내 **SSID, Password**를 실제 환경에 맞게 변경  

---

💡 위 설정이 완료되면, Arduino UNO R4 WiFi 보드는 MQTT 메시지를 수신하여  
- **IR LED 제어 (가전 제어)**  
- **서보모터 제어 (커튼 열기/닫기)**  

등의 기능을 수행할 수 있습니다.  

