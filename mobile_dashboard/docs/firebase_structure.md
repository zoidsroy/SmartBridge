# Firebase Realtime Database 구조

## 📊 전체 데이터베이스 구조
```json
{
  "control_gesture": {
    "light": {
      "swipe_up": {
        "label": "전원 켜기",
        "action": "power_on",
        "createdAt": "2024-01-15T10:30:00Z",
        "lastUsed": "2024-01-15T15:45:00Z",
        "usageCount": 25
      },
      "swipe_down": {
        "label": "전원 끄기", 
        "action": "power_off",
        "createdAt": "2024-01-15T10:30:00Z",
        "lastUsed": "2024-01-15T22:10:00Z",
        "usageCount": 18
      }
    },
    "fan": { /* 선풍기 제스쳐 설정 */ },
    "television": { /* TV 제스쳐 설정 */ }
  },
  
  "status": {
    "light": {
      "power": "on",
      "online": true,
      "brightness": 80,
      "color": "#ffffff",
      "lastUpdated": "2024-01-15T15:45:00Z"
    },
    "fan": {
      "power": "off",
      "online": true,
      "speed": 2,
      "rotation": false,
      "lastUpdated": "2024-01-15T14:30:00Z"
    }
  },
  
  "usage_stats": {
    "2024-01-15": {
      "light": {
        "deviceId": "light",
        "date": "2024-01-15",
        "totalUsage": 120,
        "gestureUsage": {
          "swipe_up": 15,
          "swipe_down": 12,
          "circle": 3
        },
        "timeSlots": ["morning", "evening"],
        "updatedAt": "2024-01-15T23:59:00Z"
      }
    }
  },
  
  "device_info": {
    "light": {
      "id": "light",
      "name": "거실 전등",
      "type": "smart_light",
      "iconPath": "assets/icons/light.png",
      "customSettings": {
        "favoriteColor": "#ffcc00",
        "autoMode": true
      },
      "createdAt": "2024-01-10T09:00:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    }
  },
  
  "routines": {
    "morning_routine": {
      "id": "morning_routine",
      "name": "모닝 루틴",
      "actions": [
        {"deviceId": "curtain", "action": "open"},
        {"deviceId": "light", "action": "power_on", "brightness": 70},
        {"deviceId": "television", "action": "power_on", "channel": "news"}
      ],
      "triggerType": "time",
      "triggerConditions": {
        "time": "07:00",
        "days": ["monday", "tuesday", "wednesday", "thursday", "friday"]
      },
      "isActive": true,
      "createdAt": "2024-01-12T20:00:00Z"
    }
  },
  
  "user_settings": {
    "theme": "light",
    "language": "ko",
    "notifications": {
      "enabled": true,
      "soundEnabled": false
    },
    "gestureSettings": {
      "sensitivity": "medium",
      "confirmBeforeAction": false
    },
    "updatedAt": "2024-01-15T10:00:00Z"
  },
  
  "user_info": {
    "fcmToken": "fXgY...",
    "updatedAt": "2024-01-15T09:00:00Z"
  }
}
```

## 🔧 주요 경로별 설명

### 1. `control_gesture/{deviceId}`
- **목적**: 기기별 제스쳐 매핑 저장
- **구조**: 제스쳐 ID를 키로 하는 매핑 정보
- **활용**: 제스쳐 커스터마이징, 사용량 추적

### 2. `status/{deviceId}`
- **목적**: 기기의 실시간 상태 저장
- **구조**: 전원, 연결상태, 기기별 고유 설정
- **활용**: 기기 제어, 상태 모니터링

### 3. `usage_stats/{date}/{deviceId}`
- **목적**: 일별 사용 통계 저장
- **구조**: 날짜별로 분류된 사용 데이터
- **활용**: 분석, 추천 시스템

### 4. `device_info/{deviceId}`
- **목적**: 기기 메타데이터 저장
- **구조**: 기기 정보, 사용자 커스터마이징
- **활용**: 기기 관리, 개인화

### 5. `routines/{routineId}`
- **목적**: 자동화 루틴 저장
- **구조**: 액션 시퀀스, 트리거 조건
- **활용**: 스마트 자동화

### 6. `user_settings`
- **목적**: 앱 전역 설정 저장
- **구조**: 테마, 언어, 알림 등
- **활용**: 사용자 경험 개인화

## 🚀 활용 방법

### 데이터 읽기 (실시간 리스닝)
```dart
// 기기 상태 실시간 모니터링
FirebaseService.getDeviceStatus('light').listen((event) {
  final status = event.snapshot.value as Map?;
  // UI 업데이트
});
```

### 데이터 쓰기
```dart
// 제스쳐 매핑 저장
await FirebaseService.saveGestureMapping(
  deviceId: 'light',
  gestureId: 'swipe_up',
  action: 'power_on',
  label: '전원 켜기',
);
```

### 사용 통계 수집
```dart
// 제스쳐 사용 시 호출
await FirebaseService.incrementGestureUsage('light', 'swipe_up');
```

## 📈 데이터 흐름

1. **제스쳐 인식** → `incrementGestureUsage()` → **통계 업데이트**
2. **기기 제어** → `updateDeviceStatus()` → **상태 반영**
3. **일일 통계** → `saveDailyUsageStats()` → **분석 데이터 축적**
4. **추천 생성** → **통계 분석** → **개인화된 제안**

## 🔐 보안 규칙 (권장)
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "user_info": {
      ".validate": "newData.hasChildren(['fcmToken'])"
    },
    "usage_stats": {
      ".write": "auth != null && now - root.child('user_info/updatedAt').val() < 86400000"
    }
  }
}
``` 