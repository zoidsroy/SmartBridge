# SmartBridge
스마트 가전이 아닌 기기까지 제어 가능한 AIoT 기반 만능 리모컨 시스템

<!-- 헤더: 움직이는 타이핑 배너 -->
<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=28&pause=1000&center=true&vCenter=true&width=750&lines=Hi%2C+I'm+SmartBridge!;AIoT+Universal+Remote+Control;Gesture+%26+Voice+Controlled;Always+learning+new+things" alt="Typing SVG" />
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

