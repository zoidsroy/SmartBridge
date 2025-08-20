flask_mqtt/
│
├── app/
│ ├── **init**.py
│ ├── routes/ ← 라우트 모듈 (API 엔드포인트)
│ │ ├── auto_train.py
│ │ ├── dashboard.py
│ │ ├── gesture.py
│ │ ├── ircode.py
│ │ ├── recommand.py
│ │ ├── status.py
│ │ └── voice.py
│ │
│ ├── services/ ← 서비스 로직 (MQTT 등)
│ │ └── mqtt_service.py
│ └── config.py ← 환경 설정 (예: Firebase URL 등)
│
├── docs/
│ └── swagger/ ← API 문서 (Swagger YAML)
│
├── firebase_config.json ← Firebase 인증 키
├── run.py
├── train.py
├── start_server.bat ← 서버+ngrok 실행 배치 스크립트
└── requirements.txt
