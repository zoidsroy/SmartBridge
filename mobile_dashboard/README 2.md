# SmartBridge Mobile Dashboard
**Flutter 크로스플랫폼 IoT 스마트홈 대시보드**

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=firebase&logoColor=white" alt="Firebase">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
</p>

## 📱 개요
SmartBridge 프로젝트의 **모바일 대시보드** 컴포넌트입니다.  
Flutter를 사용하여 iOS, Android, Web에서 실행 가능한 크로스플랫폼 앱입니다.

## 🚀 주요 기능

### 🏠 **스마트홈 제어**
- **5개 IoT 기기 지원**: 전등, 선풍기, 커튼, 에어컨, TV
- **실시간 상태 모니터링**: Firebase Realtime Database 연동
- **기기별 전용 제어**: 각 기기에 최적화된 컨트롤

### 👋 **제스처 제어**
- **18가지 제스처 지원**: 👍👎✌️🤟🤏✊👌🤘 등
- **개인별 커스터마이징**: 제스처-기기-제어 매핑 설정
- **직관적인 UI**: 그리드 기반 제스처 선택 화면

### 🎮 **리모컨 기능**
- **IR 코드 전송**: 각 기기별 적외선 리모컨 신호
- **전통적인 UI**: 기존 리모컨과 유사한 버튼 배치
- **즉시 응답**: 실시간 제어 피드백

### 🤖 **AI 추천 시스템**
- **사용 패턴 분석**: 개인별 제어 기록 기반
- **환경 정보 고려**: 온도, 시간대 등 컨텍스트
- **백엔드 API 연동**: Flask 서버와 실시간 통신

### 🔐 **사용자 관리**
- **Firebase Authentication**: 안전한 로그인/회원가입
- **프로필 관리**: 이름, 나이, 성별, 지역 정보
- **계정 복구**: 이메일, 전화번호 기반 찾기

## 🛠️ 기술 스택

### **프론트엔드**
- **Flutter 3.x**: 크로스플랫폼 UI 프레임워크
- **Dart**: 프로그래밍 언어
- **Material Design**: 구글 디자인 시스템

### **백엔드 & 데이터베이스**
- **Firebase Realtime Database**: 실시간 데이터 동기화
- **Firebase Authentication**: 사용자 인증
- **Firebase Cloud Functions**: 서버리스 백엔드
- **SharedPreferences**: 로컬 데이터 저장

### **통신**
- **HTTP**: REST API 통신
- **Firebase SDK**: 실시간 데이터 스트림
- **JSON**: 데이터 교환 포맷

## 🚀 설치 및 실행

### **1. 사전 요구사항**
```bash
# Flutter SDK 설치 확인
flutter doctor

# 의존성 설치
flutter pub get
```

### **2. 웹에서 실행**
```bash
# 크롬에서 실행
flutter run -d chrome

# HTML 렌더러 사용 (안정성)
flutter run -d chrome --web-renderer html
```

### **3. 모바일에서 실행**
```bash
# 연결된 기기에서 실행
flutter run

# 특정 기기 선택
flutter devices
flutter run -d [device-id]
```

### **4. 빌드**
```bash
# 웹 빌드
flutter build web

# Android APK 빌드
flutter build apk

# iOS 빌드 (macOS만)
flutter build ios
```

## 📁 프로젝트 구조

```
mobile_dashboard/
├── lib/
│   ├── main.dart                    # 앱 진입점
│   ├── home_screen.dart            # 홈 화면
│   ├── device_list_screen.dart     # 기기 목록
│   ├── device_detail_screen.dart   # 기기 상세 제어
│   ├── settings_screen.dart        # 설정 화면
│   ├── screens/                    # 화면 컴포넌트
│   │   ├── auth_wrapper.dart       # 인증 래퍼
│   │   ├── login_screen.dart       # 로그인
│   │   ├── signup_screen.dart      # 회원가입
│   │   ├── gesture_customization_screen.dart # 제스처 설정
│   │   ├── remote_control_screen.dart # 리모컨
│   │   └── recommendation_screen.dart # AI 추천
│   ├── services/                   # 비즈니스 로직
│   │   ├── auth_service.dart       # 인증 서비스
│   │   ├── device_service.dart     # 기기 관리
│   │   ├── gesture_service.dart    # 제스처 관리
│   │   ├── remote_control_service.dart # 리모컨 제어
│   │   └── recommendation_service.dart # AI 추천
│   └── models/                     # 데이터 모델
│       └── user_model.dart         # 사용자 모델
├── assets/                         # 리소스
│   ├── icons/                      # 기기 아이콘
│   └── data/                       # 설정 데이터
├── android/                        # Android 설정
├── ios/                           # iOS 설정
├── web/                           # Web 설정
└── test/                          # 테스트 코드
```

## 🔗 SmartBridge 생태계 연동

이 모바일 대시보드는 SmartBridge 전체 시스템의 일부입니다:

```
📡 SmartBridge 시스템
├── 🖐️ Recognition/          # 제스처/음성 인식
├── 🔧 arduino_control/      # Arduino 하드웨어
├── 🌐 Flask 서버           # 백엔드 API
└── 📱 mobile_dashboard/     # 이 모바일 앱
    ├── Firebase 연동
    ├── 백엔드 API 통신
    └── 실시간 기기 제어
```

## 🔧 개발 정보

### **주요 의존성**
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  firebase_database: ^10.4.0
  http: ^1.1.0
  shared_preferences: ^2.2.2
```

### **지원 플랫폼**
- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 11.0+)  
- ✅ **Web** (Chrome, Safari, Firefox)

### **테스트**
```bash
# 단위 테스트 실행
flutter test

# 위젯 테스트 실행
flutter test test/widget_test.dart
```

## 🔐 보안

- **Firebase Security Rules**: 데이터베이스 접근 제어
- **인증 토큰**: 안전한 사용자 식별
- **HTTPS 통신**: 모든 API 통신 암호화
- **민감 정보 제외**: 인증 키 등은 버전 관리에서 제외

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---

<p align="center">
  <b>SmartBridge Mobile Dashboard</b><br>
  <i>어디서든 스마트홈을 제어하세요! 📱🏠</i>
</p>
