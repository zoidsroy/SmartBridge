"""
통합 제스처 + 음성 인식 시스템

"""
import warnings

# Google Protobuf 관련 deprecated 경고 무시
warnings.filterwarnings("ignore", message="SymbolDatabase.GetPrototype() is deprecated")
warnings.filterwarnings("ignore", message=".*GetPrototype.*is deprecated.*")
warnings.filterwarnings("ignore", category=UserWarning, module="google.protobuf")

import cv2
import mediapipe as mp
import numpy as np
import torch
import torch.nn as nn
import pickle
import time
import glob
from collections import deque, Counter
import os

import speech_recognition as sr
import requests
import io
import wave
import Levenshtein
import threading


# ================== 서버 설정 ==================
VOICE_SERVER_URL = 'http://192.168.219.108:5000/voice'  # 음성 서버 URL
GESTURE_SERVER_URL = 'http://192.168.219.108:5000/gesture'  # 제스처 서버 URL
USER_UID = "ot2SrPF7bcdGBpm2ACDyVDwkpPF2"  # 사용자 고유 ID (Firebase UID)

# ================== 서버 전송 함수 ==================

# 전송 간격 제어 변수들
last_voice_command = None
last_voice_time = 0
last_gesture_command = None
last_gesture_time = 0
SEND_COOLDOWN = 2.0 

# 전송 간격 제어
last_sent_gesture = None
last_sent_gesture_time = 0
last_sent_voice = None
last_sent_voice_time = 0
gesture_delay = 2.0     # 다른 제스처 전송 최소 지연
gesture_resend = 5.0    # 같은 제스처 재전송 간격
voice_delay = 2.0
voice_resend = 5.0


def send_to_server(url, key, value, command_type=None):
    """서버 전송 (UID 포함, 응답 상세 확인)"""
    data = {
        "uid": USER_UID,
        key: value
    }
    if command_type:  # 음성/제스처 타입 구분
        data["type"] = command_type

    try:
        print(f"\n [서버 전송] {key}: {value} (타입: {command_type})")
        print(f" 사용자 UID: {USER_UID}")
        print(f" 전송 URL: {url}")
        print(f" 전송 데이터: {data}")
        
        response = requests.post(url, json=data, timeout=10)
        
        # 응답 상세 정보 출력
        print(f"\n  [서버 응답]")
        print(f"   상태 코드: {response.status_code}")
        print(f"   응답 시간: {response.elapsed.total_seconds():.3f}초")
        print(f"   응답 헤더: {dict(response.headers)}")
        print(f"   응답 본문: '{response.text}'")
        print(f"   응답 길이: {len(response.text)} 문자")
        
        if response.status_code == 200:
            print(f"  전송 성공! 서버가 정상적으로 응답했습니다.")
            if response.text:
                print(f"  서버 메시지: {response.text}")
            else:
                print(f"  서버에서 빈 응답을 받았습니다.")
        elif response.status_code == 404:
            print(f"  404 오류: URL이 잘못되었거나 서버에 해당 엔드포인트가 없습니다.")
            print(f"  확인사항: {url} 경로가 올바른지 확인하세요.")
        elif response.status_code == 500:
            print(f"  500 오류: 서버 내부 오류가 발생했습니다.")
            print(f"  서버 로그를 확인해보세요.")
        else:
            print(f"  예상치 못한 응답 코드: {response.status_code}")
            
    except requests.exceptions.ConnectionError as e:
        print(f"  [연결 오류] 서버에 연결할 수 없습니다.")
        print(f"   오류 내용: {e}")
    except requests.exceptions.Timeout as e:
        print(f"  [타임아웃] 서버 응답이 10초를 초과했습니다.")
        print(f"   오류 내용: {e}")
    except Exception as e:
        print(f"  [예상치 못한 오류] {type(e).__name__}: {e}")
        
    print("="*50)


# ==================== 제스처 전송 ====================
def try_send_gesture(gesture):
    global last_sent_gesture, last_sent_gesture_time
    now = time.time()

    if gesture != last_sent_gesture:
        if now - last_sent_gesture_time >= gesture_delay:
            threading.Thread(
                target=send_to_server,
                args=(GESTURE_SERVER_URL, "gesture", gesture),  # 제스처는 타입 필요 없음
                daemon=True
            ).start()
            last_sent_gesture = gesture
            last_sent_gesture_time = now
            print(f"[제스처 전송] sent: {gesture}")

    elif now - last_sent_gesture_time >= gesture_resend:
        threading.Thread(
            target=send_to_server,
            args=(GESTURE_SERVER_URL, "gesture", gesture),
            daemon=True
        ).start()
        last_sent_gesture_time = now
        print(f"[제스처 전송] re-sent: {gesture}")


# ==================== 음성 전송 ====================
def try_send_voice(voice_command):
    global last_sent_voice, last_sent_voice_time
    now = time.time()

    if voice_command != last_sent_voice:
        if now - last_sent_voice_time >= voice_delay:
            threading.Thread(
                target=send_to_server,
                args=(VOICE_SERVER_URL, "voice", voice_command, "voice"),
                daemon=True
            ).start()
            last_sent_voice = voice_command
            last_sent_voice_time = now
            print(f"[음성 전송] sent: {voice_command}")

    elif now - last_sent_voice_time >= voice_resend:
        threading.Thread(
            target=send_to_server,
            args=(VOICE_SERVER_URL, "voice", voice_command, "voice"),
            daemon=True
        ).start()
        last_sent_voice_time = now
        print(f"[음성 전송] re-sent: {voice_command}")


# 기존 함수들 (호환성을 위해 유지)
def send_voice_to_server(voice_command):
    """서버에 음성 명령어 전송 (UID 포함, 응답 상세 확인)"""
    try_send_voice(voice_command)

def send_gesture_to_server(gesture_label):
    """서버에 제스처 신호 전송 (UID 포함, 음성과 동일한 형식)"""
    try_send_gesture(gesture_label)
        
    print(f"{'='*50}")  # 구분선

# ================== 액션 → 제스처 매핑 ==================
action_to_gesture_map = {
    # 기존 명령어들
    'light_on': 'light_on',
    'light_off': 'light_off',
    'ac_on': 'ac_on',
    'ac_off': 'ac_off',
    'fan_on': 'fan_on',
    'fan_off': 'fan_off',
    'curtain_open': 'curtain_open',
    'curtain_close': 'curtain_close',
    'tv_on': 'tv_on',
    'tv_off': 'tv_off',
    'temp_up': 'small_heart',
    'temp_down': 'small_heart',
    
    # 선풍기 제어 명령어들
    'fan_horizontal': 'horizontal',        # 수평방향 회전
    'fan_mode': 'mode',                    # 모드 전환
    'fan_stronger': 'stronger',            # 바람세기+
    'fan_timer': 'timer',                  # 타이머 설정
    'fan_vertical': 'vertical',            # 수직방향 회전
    'fan_weaker': 'weaker',                # 바람세기-
    
    # 조명 제어 명령어들
    'light_10min': 'light_10min',                # 타이머 10분 설정
    'light_2min': 'light_2min',                  # 타이머 2분 설정
    'light_30min': 'light_30min',                # 타이머 30분 설정
    'light_60min': 'light_60min',                # 타이머 1시간 설정
    'light_brighter': 'light_brighter',          # 밝기+
    'light_color': 'light_color',                # 전등색 변경
    'light_dimmer': 'light_dimmer',              # 밝기-
    
    # 새로운 매핑 추가
    'ac_mode': 'ac_mode',                        # 에어컨 모드
    'ac_power': 'ac_power',                      # 에어컨 전원
    'ac_temp_down': 'ac_tempDOWN',               # 에어컨 온도 다운
    'ac_temp_up': 'ac_tempUP',                   # 에어컨 온도 업
    'tv_power': 'tv_power',                      # TV 전원
    'tv_channel_up': 'tv_channelUP',             # TV 채널 업
    'tv_channel_down': 'tv_channelDOWN',         # TV 채널 다운
    'spider_man': 'spider_man',                  # 스파이더맨
    'small_heart': 'small_heart',                # 작은 하트
    'thumbs_down': 'thumbs_down',                # 엄지 다운
    'thumbs_up': 'thumbs_up',                    # 엄지 업
    'thumbs_left': 'thumbs_left',                # 엄지 왼쪽
    'thumbs_right': 'thumbs_right'               # 엄지 오른쪽
}

# TTS (Text-to-Speech) 라이브러리
try:
    import pyttsx3
    TTS_AVAILABLE = True
    print("  TTS 사용 가능 (음성 응답)")
except ImportError:
    TTS_AVAILABLE = False
    print("  TTS 없음 - pip install pyttsx3")

# Windows SAPI 백업 시도
try:
    import win32com.client
    SAPI_AVAILABLE = True
    print("  Windows SAPI 사용 가능 (백업 TTS)")
except ImportError:
    SAPI_AVAILABLE = False
    print("  Windows SAPI 없음 (선택사항)")

# 사운드 재생용
try:
    import winsound
    SOUND_AVAILABLE = True
    print("  시스템 사운드 사용 가능")
except ImportError:
    SOUND_AVAILABLE = False
    print("  시스템 사운드 없음")

# ================== 사운드 재생 시스템 ==================
def play_notification_sound(sound_type="system"):
    """웨이크워드 감지 시 알림음 재생"""
    if not SOUND_AVAILABLE:
        return
    
    try:
        if sound_type == "system":
            # Windows 시스템 알림음 (띠롱 같은 소리)
            winsound.MessageBeep(winsound.MB_OK)
            print("  시스템 알림음 재생")
        elif sound_type == "question":
            # 질문 소리 (다른 톤)
            winsound.MessageBeep(winsound.MB_ICONQUESTION)
            print("  질문 알림음 재생")
        elif sound_type == "beep":
            # 단순 비프음
            winsound.Beep(800, 200)  # 800Hz, 200ms
            print("  비프음 재생")
        else:
            # 기본 시스템 알림음
            winsound.MessageBeep(-1)
            print("  기본 알림음 재생")
    except Exception as e:
        try:
            # 백업: 단순 비프음
            winsound.Beep(800, 200)
            print("  백업 비프음 재생")
        except Exception as e2:
            print(f"  사운드 재생 실패: {e2}")

def play_beep_sequence():
    """웨이크워드 감지 시 특별한 비프 시퀀스"""
    if not SOUND_AVAILABLE:
        return
    
    def beep_sequence():
        try:
            # "띠-링-롱" 같은 3음 시퀀스 (더 친숙한 소리)
            winsound.Beep(880, 120)   # 높은 음 (띠)
            time.sleep(0.03)
            winsound.Beep(1100, 120)  # 더 높은 음 (링) 
            time.sleep(0.03)
            winsound.Beep(660, 250)   # 낮은 음 (롱)
        except Exception as e:
            print(f"🔇 멜로디 재생 실패: {e}")
    
    try:
        threading.Thread(target=beep_sequence, daemon=True).start()
        print("  웨이크워드 멜로디 재생")
    except Exception as e:
        print(f"  멜로디 스레드 실패: {e}")
        # 백업: 간단한 알림음
        play_notification_sound()

# ================== TTS (음성 응답) 시스템 ==================
class TTSSystem:
    def __init__(self):
        self.engine = None
        self.sapi_engine = None
        self.is_speaking = False
        self.use_sapi = False
        self._initialize()

    def _initialize(self):
        """TTS 엔진 초기화 (SAPI 우선, pyttsx3 백업)"""
        print(f"  TTS 초기화 시작...")

        # 1차 시도: Windows SAPI (더 안정적)
        if SAPI_AVAILABLE:
            try:
                print("  [1차] Windows SAPI 시도...")
                test_sapi = win32com.client.Dispatch("SAPI.SpVoice")
                print("  Windows SAPI 초기화 성공!")
                self.sapi_engine = test_sapi
                self.use_sapi = True
                return
            except Exception as e:
                print(f"  Windows SAPI 초기화 실패: {e}")

        # 2차 시도: pyttsx3
        if TTS_AVAILABLE:
            try:
                print("  [2차] pyttsx3 시도...")
                test_engine = pyttsx3.init()
                test_engine.setProperty('rate', 200)
                test_engine.setProperty('volume', 0.9)
                print("  pyttsx3 초기화 성공!")
                self.engine = test_engine
                return
            except Exception as e:
                print(f"  pyttsx3 초기화 실패: {e}")

        print("  모든 TTS 엔진 초기화 실패!")

    def speak(self, text, async_mode=True):
        """텍스트를 음성으로 변환"""
        if not self.use_sapi and not self.engine:
            return

        try:
            print(f"  TTS: '{text}' (엔진: {'SAPI' if self.use_sapi else 'pyttsx3'})")
            if async_mode:
                threading.Thread(target=self._speak_sync, args=(text,), daemon=True).start()
            else:
                self._speak_sync(text)
        except Exception as e:
            print(f"  TTS 오류: {e}")

    def _speak_sync(self, text):
        """동기 음성 출력"""
        try:
            self.is_speaking = True

            # SAPI 사용
            if self.use_sapi and self.sapi_engine:
                try:
                    self.sapi_engine.Speak(text)
                    self.is_speaking = False
                    return
                except Exception as e:
                    print(f"  SAPI 출력 오류: {e}")

            # pyttsx3 사용
            if self.engine:
                try:
                    self.engine.say(text)
                    self.engine.runAndWait()
                    self.is_speaking = False
                    return
                except Exception as e:
                    print(f"  pyttsx3 출력 오류: {e}")

            self.is_speaking = False

        except Exception as e:
            print(f"  TTS 출력 치명적 오류: {e}")
            self.is_speaking = False

# ================== 설정 ==================
WAKE_PATTERNS = ["브릿지", "스마트브릿지", "브리치", "브리찌", "응답", "스마트"]
WAKE_KEYWORDS = ["브릿지", "브리치", "스마트", "응답"]
PHRASE_TIME_LIMIT = 2
AMBIENT_DURATION = 0.3

# ================== 웨이크워드 감지 ==================
def normalize(text):
    return text.lower().replace(" ", "").replace("-", "")

def detect_wake_word(text):
    norm = normalize(text)
    for kw in WAKE_KEYWORDS:
        if kw in norm:
            print(f"  빠른 매칭: '{kw}' 포함됨")
            return True
    for pattern in WAKE_PATTERNS:
        if Levenshtein.distance(norm, normalize(pattern)) <= 2:
            print(f"  유사 웨이크워드 감지: '{text}' ≈ '{pattern}'")
            return True
    return False

# ================== Colab으로 명령어 전송 ==================
def send_to_colab(audio_path, colab_url):
    try:
        print(f"  Colab에 오디오 전송 중... → {colab_url}/infer")
        
        # 파일을 올바르게 열고 닫기
        with open(audio_path, 'rb') as audio_file:
            files = {'audio': audio_file}
            response = requests.post(f"{colab_url}/infer", files=files)

        print("  응답 상태 코드:", response.status_code)
        print("  응답 본문:", response.text)

        # 단순 텍스트 파싱: "텍스트|액션" 또는 "ERROR|메시지"
        response_text = response.text.strip()

        if "|" in response_text:
            parts = response_text.split("|", 1)  # 최대 1번만 분할
            if len(parts) == 2:
                left_part = parts[0].strip()
                right_part = parts[1].strip()

                # 에러 응답인지 확인
                if left_part == "ERROR":
                    return {'error': right_part}
                else:
                    # 정상 응답: "인식텍스트|액션"
                    return {
                        "text": left_part,
                        "action": right_part
                    }

        # "|"가 없는 경우 (예상치 못한 응답)
        return {
            "text": response_text,
            "action": "none"
        }

    except Exception as e:
        return {'error': str(e)}

# ================== 오디오 녹음 ==================
def record_audio(filename="command.wav", duration=3):
    recognizer = sr.Recognizer()
    mic = sr.Microphone()
    with mic as source:
        print("  명령어를 말하세요...")
        recognizer.adjust_for_ambient_noise(source, duration=AMBIENT_DURATION)
        try:
            audio = recognizer.listen(source, timeout=5, phrase_time_limit=duration)
        except sr.WaitTimeoutError:
            print("  타임아웃: 사용자가 말을 시작하지 않았습니다.")
            return None

        with open(filename, "wb") as f:
            f.write(audio.get_wav_data())
    return filename

# ================== 웨이크워드 루프 ==================
def wait_for_wake_word(recognizer, mic):
    with mic as source:
        print("  웨이크워드 대기 중 ('브릿지')")
        recognizer.adjust_for_ambient_noise(source, duration=AMBIENT_DURATION)
        audio = recognizer.listen(source, timeout=5, phrase_time_limit=PHRASE_TIME_LIMIT)
        return audio


# 통합 인식 설정
INTEGRATED_CONFIG = {
    # 모델 파일
    'mlp_model_pattern': 'MLP_model.pth',
    'tcn_model_pattern': 'TCN_model.pth',
    'mlp_scaler_file': 'MLP_scaler.pkl',
    'tcn_scaler_file': 'TCN_scaler.pkl',
    
    # 인식 설정 (더 유연하게 조정)
    'static_confidence_threshold': 0.7,        # 정적 제스처 신뢰도 임계값
    'dynamic_confidence_threshold': 0.6,       # 동적 제스처 신뢰도 임계값
    'movement_threshold': 0.02,                # 움직임 감지 임계값 (더 민감하게)
    'movement_duration_threshold': 0.3,        # 움직임 지속 시간 임계값 (더 짧게)
    'static_hold_time': 1.0,                   # 정적 제스처 유지 시간 (초)
    'dynamic_sequence_time': 1.0,              # 동적 시퀀스 수집 시간 (2.0→1.0초로 단축)
    'dynamic_completion_wait': 1.5,            # 동적 제스처 완료 대기 시간 (신규)
    'prediction_cooldown': 1.0,                # 예측 후 대기 시간 (더 짧게)
    'static_stability_time': 0.3,              # 정적 안정화 시간 (더 짧게)
    
    # MediaPipe 설정
    'min_detection_confidence': 0.7,
    'min_tracking_confidence': 0.5,
    
    # UI 설정
    'fps_display': True,
    'trail_display': True,
    'debug_mode': False,
}

# 색상 설정 (BGR)
COLORS = {
    'static_mode': (0, 255, 0),       # 초록색 (정적 모드)
    'dynamic_mode': (255, 0, 255),    # 마젠타 (동적 모드)
    'movement': (0, 255, 255),        # 노란색 (움직임 감지)
    'processing': (255, 255, 0),      # 시안 (처리 중)
    'predicted': (255, 0, 255),       # 마젠타 (예측 완료)
    'waiting': (255, 255, 255),       # 흰색 (대기)
    'no_hand': (0, 0, 255),          # 빨간색 (손 없음)
    'text': (255, 255, 255),         # 흰색 (텍스트)
    'bg': (50, 50, 50),              # 회색 (배경)
    'trail': (0, 165, 255),          # 주황색 (궤적)
    'good': (0, 255, 0),             # 초록색 (높은 신뢰도)
    'medium': (0, 255, 255),         # 노란색 (중간 신뢰도)
    'low': (0, 165, 255),            # 주황색 (낮은 신뢰도)
}


class ExistingDataMLP(nn.Module):
    """기존 데이터용 MLP 모델"""
    
    def __init__(self, input_dim=99, num_classes=15, hidden_sizes=[512, 256, 128, 64], 
                 dropout_rate=0.4, use_batch_norm=True):
        super(ExistingDataMLP, self).__init__()
        
        self.input_dim = input_dim
        self.num_classes = num_classes
        self.use_batch_norm = use_batch_norm
        
        # 입력층 정규화
        if use_batch_norm:
            self.input_norm = nn.BatchNorm1d(input_dim)
        
        # 네트워크 구성
        layers = []
        prev_size = input_dim
        
        for i, hidden_size in enumerate(hidden_sizes):
            layers.append(nn.Linear(prev_size, hidden_size))
            if use_batch_norm:
                layers.append(nn.BatchNorm1d(hidden_size))
            layers.append(nn.ReLU(inplace=True))
            layers.append(nn.Dropout(dropout_rate))
            prev_size = hidden_size
        
        layers.append(nn.Linear(prev_size, num_classes))
        self.network = nn.Sequential(*layers)
        
        self._initialize_weights()
    
    def _initialize_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
    
    def forward(self, x):
        # 배치 크기가 1인 경우 BatchNorm 우회
        if x.size(0) == 1 and hasattr(self, 'input_norm'):
            if self.input_norm.running_mean is not None:
                epsilon = self.input_norm.eps
                mean = self.input_norm.running_mean
                var = self.input_norm.running_var
                weight = self.input_norm.weight
                bias = self.input_norm.bias
                
                x_norm = (x - mean) / torch.sqrt(var + epsilon)
                if weight is not None:
                    x_norm = x_norm * weight
                if bias is not None:
                    x_norm = x_norm + bias
                x = x_norm
        else:
            if hasattr(self, 'input_norm'):
                x = self.input_norm(x)
        
        return self.network(x)


class Chomp1d(nn.Module):
    def __init__(self, chomp_size):
        super(Chomp1d, self).__init__()
        self.chomp_size = chomp_size

    def forward(self, x):
        return x[:, :, :-self.chomp_size].contiguous()

class TemporalBlock(nn.Module):
    def __init__(self, n_inputs, n_outputs, kernel_size, stride, dilation, padding, dropout=0.2, use_batch_norm=True):
        super(TemporalBlock, self).__init__()
        
        self.conv1 = nn.Conv1d(n_inputs, n_outputs, kernel_size,
                               stride=stride, padding=padding, dilation=dilation)
        self.chomp1 = Chomp1d(padding)
        self.bn1 = nn.BatchNorm1d(n_outputs) if use_batch_norm else nn.Identity()
        self.relu1 = nn.ReLU()
        self.dropout1 = nn.Dropout(dropout)

        self.conv2 = nn.Conv1d(n_outputs, n_outputs, kernel_size,
                               stride=stride, padding=padding, dilation=dilation)
        self.chomp2 = Chomp1d(padding)
        self.bn2 = nn.BatchNorm1d(n_outputs) if use_batch_norm else nn.Identity()
        self.relu2 = nn.ReLU()
        self.dropout2 = nn.Dropout(dropout)

        self.downsample = nn.Conv1d(n_inputs, n_outputs, 1) if n_inputs != n_outputs else None
        self.relu = nn.ReLU()

    def forward(self, x):
        out = self.conv1(x)
        out = self.chomp1(out)
        out = self.bn1(out)
        out = self.relu1(out)
        out = self.dropout1(out)

        out = self.conv2(out)
        out = self.chomp2(out)
        out = self.bn2(out)
        out = self.relu2(out)
        out = self.dropout2(out)

        res = x if self.downsample is None else self.downsample(x)
        return self.relu(out + res)

class TemporalConvNet(nn.Module):
    def __init__(self, num_inputs, num_channels, kernel_size=2, dropout=0.2, use_batch_norm=True):
        super(TemporalConvNet, self).__init__()
        layers = []
        num_levels = len(num_channels)
        
        for i in range(num_levels):
            dilation_size = 2 ** i
            in_channels = num_inputs if i == 0 else num_channels[i-1]
            out_channels = num_channels[i]
            padding = (kernel_size - 1) * dilation_size
            
            layers += [TemporalBlock(in_channels, out_channels, kernel_size, stride=1, dilation=dilation_size,
                                   padding=padding, dropout=dropout, use_batch_norm=use_batch_norm)]

        self.network = nn.Sequential(*layers)

    def forward(self, x):
        return self.network(x)

class SequenceTCN(nn.Module):
    def __init__(self, input_features, num_classes, tcn_channels, kernel_size=3, 
                 dropout_rate=0.3, use_skip_connections=True, use_batch_norm=True):
        super(SequenceTCN, self).__init__()
        
        self.input_features = input_features
        self.num_classes = num_classes
        
        if use_batch_norm:
            self.input_norm = nn.BatchNorm1d(input_features)
        
        self.tcn = TemporalConvNet(input_features, tcn_channels, kernel_size, dropout_rate, use_batch_norm)
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        
        self.classifier = nn.Sequential(
            nn.Linear(tcn_channels[-1], tcn_channels[-1] // 2),
            nn.BatchNorm1d(tcn_channels[-1] // 2) if use_batch_norm else nn.Identity(),
            nn.ReLU(),
            nn.Dropout(dropout_rate),
            nn.Linear(tcn_channels[-1] // 2, num_classes)
        )
    
    def forward(self, x):
        x = x.transpose(1, 2)
        
        if hasattr(self, 'input_norm'):
            if x.size(0) == 1:
                if self.input_norm.running_mean is not None:
                    epsilon = self.input_norm.eps
                    mean = self.input_norm.running_mean.unsqueeze(0).unsqueeze(-1)
                    var = self.input_norm.running_var.unsqueeze(0).unsqueeze(-1)
                    weight = self.input_norm.weight.unsqueeze(0).unsqueeze(-1) if self.input_norm.weight is not None else None
                    bias = self.input_norm.bias.unsqueeze(0).unsqueeze(-1) if self.input_norm.bias is not None else None
                    
                    x_norm = (x - mean) / torch.sqrt(var + epsilon)
                    if weight is not None:
                        x_norm = x_norm * weight
                    if bias is not None:
                        x_norm = x_norm + bias
                    x = x_norm
            else:
                x = self.input_norm(x)
        
        tcn_out = self.tcn(x)
        pooled = self.global_pool(tcn_out)
        pooled = pooled.squeeze(-1)
        output = self.classifier(pooled)
        
        return output


class IntegratedGestureRecognizer:
    """통합 제스처 인식기 (MLP + TCN)"""
    
    def __init__(self, config):
        self.config = config
        self.reset_state()
        
        # 모델 및 스케일러 로딩
        self.mlp_model, self.mlp_scaler, self.mlp_labels = self.load_mlp_model()
        self.tcn_model, self.tcn_scaler, self.tcn_labels = self.load_tcn_model()
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        
        if self.mlp_model:
            self.mlp_model = self.mlp_model.to(self.device)
        if self.tcn_model:
            self.tcn_model = self.tcn_model.to(self.device)
        
        # 새로운 제스처 레이블 매핑 추가
        self.add_new_gesture_labels()
        
        print(f"  디바이스: {self.device}")
        
    def reset_state(self):
        """상태 초기화"""
        self.mode = "static"  # static을 기본값으로 변경
        self.sequence_buffer = deque(maxlen=60)  # TCN용 시퀀스 버퍼
        self.trail_points = deque(maxlen=50)     # 궤적 표시용
        self.static_buffer = deque(maxlen=10)    # 정적 제스처 안정화용
        
        # 움직임 감지 (더 민감한 기준)
        self.last_finger_pos = None
        self.movement_history = deque(maxlen=15)  # 더 짧은 히스토리로 빠른 반응
        self.is_moving = False
        self.movement_start_time = 0
        self.static_start_time = time.time()  # 처음에 정적 시간 시작
        self.last_stable_time = time.time()   # 마지막으로 안정된 시간
        self.continuous_movement_time = 0     # 연속 움직임 시간
        
        # 예측 관련
        self.last_prediction = None
        self.last_prediction_time = 0
        self.prediction_confidence = 0.0
        self.prediction_source = ""  # "static" or "dynamic"
        
        # 화면 표시용 (서버 전송 후에도 유지)
        self.display_prediction = None
        self.display_confidence = 0.0
        self.display_source = ""
        self.display_gesture_name = ""
        self.display_time = 0
        
        print("  상태 및 화면 표시 초기화 완료")
    
    def add_new_gesture_labels(self):
        """새로운 제스처 레이블 매핑 추가"""
        print("  새로운 제스처 레이블 매핑 추가 중...")
        
        # MLP 레이블에 새로운 제스처 추가
        if self.mlp_labels is not None:
            new_mlp_labels = {
                'ac_mode': 'ac_mode',
                'ac_power': 'ac_power', 
                'ac_tempDOWN': 'ac_tempDOWN',
                'ac_tempUP': 'ac_tempUP',
                'tv_power': 'tv_power',
                'tv_channelUP': 'tv_channelUP',
                'tv_channelDOWN': 'tv_channelDOWN',
                'spider_man': 'spider_man',
                'small_heart': 'small_heart',
                'thumbs_down': 'thumbs_down',
                'thumbs_up': 'thumbs_up',
                'thumbs_left': 'thumbs_left',
                'thumbs_right': 'thumbs_right'
            }
            
            # 기존 레이블과 병합
            self.mlp_labels.update(new_mlp_labels)
            print(f"     MLP 레이블에 {len(new_mlp_labels)}개 제스처 추가")
        
        # TCN 레이블에 새로운 제스처 추가
        if self.tcn_labels is not None:
            new_tcn_labels = {
                'ac_mode': 'ac_mode',
                'ac_power': 'ac_power',
                'ac_tempDOWN': 'ac_tempDOWN', 
                'ac_tempUP': 'ac_tempUP',
                'tv_power': 'tv_power',
                'tv_channelUP': 'tv_channelUP',
                'tv_channelDOWN': 'tv_channelDOWN',
                'spider_man': 'spider_man',
                'small_heart': 'small_heart',
                'thumbs_down': 'thumbs_down',
                'thumbs_up': 'thumbs_up',
                'thumbs_left': 'thumbs_left',
                'thumbs_right': 'thumbs_right'
            }
            
            # 기존 레이블과 병합
            self.tcn_labels.update(new_tcn_labels)
            print(f"     TCN 레이블에 {len(new_tcn_labels)}개 제스처 추가")
        
        print("     새로운 제스처 레이블 매핑 완료")
    
    def load_mlp_model(self):
        """MLP 모델 로딩"""
        print("  MLP 모델 로딩 중...")
        
        model_files = glob.glob(self.config['mlp_model_pattern'])
        if not model_files:
            print(f"  MLP 모델을 찾을 수 없습니다: {self.config['mlp_model_pattern']}")
            return None, None, None
        
        try:
            latest_model = max(model_files, key=os.path.getctime)
            checkpoint = torch.load(latest_model, map_location='cpu')
            config = checkpoint['config']
            
            # 라벨 정보 추출
            if 'gesture_labels' in checkpoint:
                labels = checkpoint['gesture_labels']
                label_to_name = checkpoint['label_to_name']
            else:
                labels = {}
                label_to_name = {}
            
            # 모델 생성
            model = ExistingDataMLP(
                input_dim=config['input_dim'],
                num_classes=config['num_classes'],
                hidden_sizes=config['hidden_sizes'],
                dropout_rate=config['dropout_rate'],
                use_batch_norm=config['use_batch_norm']
            )
            
            model.load_state_dict(checkpoint['model_state_dict'])
            model.eval()
            
            # 스케일러 로딩
            with open(self.config['mlp_scaler_file'], 'rb') as f:
                scaler = pickle.load(f)
            
            print(f"     MLP 모델 로딩 완료")
            print(f"      - 정적 제스처: {list(labels.keys())}")
            
            return model, scaler, label_to_name
            
        except Exception as e:
            print(f"     MLP 모델 로딩 실패: {e}")
            return None, None, None
    
    def load_tcn_model(self):
        """TCN 모델 로딩"""
        print("  TCN 모델 로딩 중...")
        
        model_files = glob.glob(self.config['tcn_model_pattern'])
        if not model_files:
            print(f"  TCN 모델을 찾을 수 없습니다: {self.config['tcn_model_pattern']}")
            return None, None, None
        
        try:
            latest_model = max(model_files, key=os.path.getctime)
            checkpoint = torch.load(latest_model, map_location='cpu')
            config = checkpoint['config']
            
            # 라벨 정보 추출
            if 'gesture_labels' in checkpoint:
                labels = checkpoint['gesture_labels']
                label_to_name = checkpoint['label_to_name']
            elif 'unique_gestures' in checkpoint and 'gesture_to_label' in checkpoint:
                labels = checkpoint['gesture_to_label']
                label_to_name = {v: k for k, v in checkpoint['gesture_to_label'].items()}
            else:
                labels = {}
                label_to_name = {}
            
            # 모델 생성
            model = SequenceTCN(
                input_features=config['input_features'],
                num_classes=config['num_classes'],
                tcn_channels=config['tcn_channels'],
                kernel_size=config['kernel_size'],
                dropout_rate=config['dropout_rate'],
                use_skip_connections=config['use_skip_connections'],
                use_batch_norm=config['use_batch_norm']
            )
            
            model.load_state_dict(checkpoint['model_state_dict'])
            model.eval()
            
            # 스케일러 로딩
            with open(self.config['tcn_scaler_file'], 'rb') as f:
                scaler = pickle.load(f)
            
            print(f"     TCN 모델 로딩 완료")
            print(f"      - 동적 제스처: {list(labels.keys())}")
            
            return model, scaler, label_to_name
            
        except Exception as e:
            print(f"     TCN 모델 로딩 실패: {e}")
            return None, None, None
    
    def detect_movement(self, finger_tip):
        """개선된 움직임 감지 - 더 민감하고 유연한 Dynamic 모드 전환"""
        current_time = time.time()
        
        if finger_tip is None:
            # 손이 없으면 정적 모드로 복귀
            self.is_moving = False
            self.mode = "static"
            self.static_start_time = current_time
            self.last_stable_time = current_time
            return False
        
        if self.last_finger_pos is not None:
            # 이전 위치와의 거리 계산
            distance = np.sqrt((finger_tip[0] - self.last_finger_pos[0])**2 + 
                             (finger_tip[1] - self.last_finger_pos[1])**2)
            
            # 움직임 히스토리에 추가
            self.movement_history.append(distance)
            
            # 더 짧은 윈도우로 빠른 반응
            if len(self.movement_history) >= 5:  # 10에서 5로 줄임
                avg_movement = np.mean(list(self.movement_history)[-8:])   # 최근 8프레임
                max_movement = np.max(list(self.movement_history)[-3:])    # 최근 3프레임 최대값
                recent_movement = np.mean(list(self.movement_history)[-3:])  # 최근 3프레임 평균
                
                # 움직임 감지 기준 완화 (OR 조건으로 더 민감하게)
                is_significant_movement = (
                    avg_movement > self.config['movement_threshold'] or 
                    max_movement > self.config['movement_threshold'] * 1.2 or
                    recent_movement > self.config['movement_threshold'] * 0.8  # 추가 조건
                )
                
                if is_significant_movement:
                    if not self.is_moving:
                        # 움직임 시작
                        self.movement_start_time = current_time
                        self.is_moving = True
                        print(f"  움직임 감지 시작: avg={avg_movement:.3f}, max={max_movement:.3f}")
                    
                    # 연속 움직임 시간 계산
                    self.continuous_movement_time = current_time - self.movement_start_time
                    
                    # 더 짧은 시간으로 Dynamic 모드 진입 (1초 → 0.5초)
                    if self.continuous_movement_time >= self.config['movement_duration_threshold']:
                        if self.mode != "dynamic":
                            self.mode = "dynamic"
                            print(f"  Dynamic 모드 진입 ({self.continuous_movement_time:.1f}초)")
                        return True
                    
                else:
                    # 움직임이 멈춤
                    if self.is_moving:
                        self.is_moving = False
                        self.last_stable_time = current_time
                        print(f"  움직임 정지 (지속시간: {self.continuous_movement_time:.1f}초)")
                        
                        # Dynamic 모드였다면 Static으로 복귀하기 전 잠시 대기
                        if self.mode == "dynamic":
                            # Dynamic 예측을 위한 시간 확보
                            pass
                        else:
                            # 즉시 Static 모드로
                            self.mode = "static"
                            self.static_start_time = current_time
                    
                    # Static 모드 복귀 조건 (더 빠르게)
                    stable_duration = current_time - self.last_stable_time
                    if stable_duration >= self.config['static_stability_time']:
                        if self.mode != "static":
                            self.mode = "static"
                            self.static_start_time = current_time
                            print(f"  Static 모드 복귀 (안정화: {stable_duration:.1f}초)")
                    
                    return False
        
        self.last_finger_pos = finger_tip
        return False
    
    def add_frame(self, mlp_features, tcn_features, finger_tip=None, hand_detected=False):
        """프레임 추가 (MLP용과 TCN용 특징을 각각 처리)"""
        current_time = time.time()
        
        if not hand_detected or mlp_features is None:
            # 손이 없을 때 상태 초기화
            self.last_finger_pos = None
            self.movement_history.clear()
            self.is_moving = False
            return
        
        # 움직임 감지
        is_moving = self.detect_movement(finger_tip)
        
        # 궤적 포인트 추가
        if finger_tip is not None:
            self.trail_points.append(finger_tip)
        
        # 시퀀스 버퍼에 TCN용 특징 추가
        if tcn_features is not None:
            self.sequence_buffer.append(tcn_features)
        
        # 정적 제스처용 버퍼에 MLP용 특징 추가 (움직임이 적을 때)
        if not is_moving:
            self.static_buffer.append(mlp_features)
    
    def should_predict_static(self):
        """정적 제스처 예측 여부 - Static 모드 우선"""
        current_time = time.time()
        
        # 조건: Static 모드 + 충분한 데이터 + 일정 시간 유지
        is_static_mode = self.mode == "static"
        has_data = len(self.static_buffer) >= 5
        not_moving = not self.is_moving
        held_long_enough = (current_time - self.static_start_time) >= self.config['static_hold_time']
        cooldown_passed = (current_time - self.last_prediction_time) >= self.config['prediction_cooldown']
        
        return is_static_mode and has_data and not_moving and held_long_enough and cooldown_passed
    
    def should_predict_dynamic(self):
        """동적 제스처 예측 여부 - 중복 예측 방지 강화"""
        current_time = time.time()
        
        # 조건: Dynamic 모드였던 경험 + 충분한 시퀀스 데이터 + 움직임 패턴 완료
        was_dynamic_mode = self.mode == "dynamic" or (self.movement_start_time > 0 and self.continuous_movement_time >= self.config['movement_duration_threshold'])
        has_data = len(self.sequence_buffer) >= 60
        
        # 개선된 움직임 완료 조건: 손이 화면에 있어도 일정 시간 움직임이 없으면 OK
        movement_pattern_complete = (
            # 기존: 완전히 멈춤 (손이 나간 경우)
            (self.is_moving == False and self.movement_start_time > 0) or
            # 신규: 손이 있지만 충분히 오래 안정된 경우 (1초)
            (not self.is_moving and (current_time - self.last_stable_time) >= 1.0) or
            # 신규: Dynamic 모드에서 충분한 시간이 지남
            (self.mode == "dynamic" and (current_time - self.movement_start_time) >= self.config['dynamic_completion_wait'])
        )
        
        # 시퀀스 시간 조건 완화
        sequence_time = (current_time - self.last_stable_time) >= self.config['dynamic_sequence_time']
        cooldown_passed = (current_time - self.last_prediction_time) >= self.config['prediction_cooldown']
        significant_movement = self.continuous_movement_time >= self.config['movement_duration_threshold']
        
        # 중복 방지: 최근에 같은 소스로 예측했다면 더 오랜 시간 대기
        if self.prediction_source == "dynamic":
            extended_cooldown = (current_time - self.last_prediction_time) >= (self.config['prediction_cooldown'] * 3)
            return was_dynamic_mode and has_data and movement_pattern_complete and extended_cooldown and significant_movement
        
        return was_dynamic_mode and has_data and movement_pattern_complete and cooldown_passed and significant_movement
    
    def predict_static(self):
        """정적 제스처 예측"""
        if not self.mlp_model or len(self.static_buffer) == 0:
            return None, 0.0
        
        try:
            # 최근 프레임들의 평균 사용
            features = np.mean(list(self.static_buffer), axis=0)
            features_scaled = self.mlp_scaler.transform(features.reshape(1, -1))
            features_tensor = torch.FloatTensor(features_scaled).to(self.device)
            
            with torch.no_grad():
                outputs = self.mlp_model(features_tensor)
                probabilities = torch.softmax(outputs, dim=1)
                confidence, predicted = torch.max(probabilities, 1)
                
                predicted_class = predicted.item()
                confidence_score = confidence.item()
            
            return predicted_class, confidence_score
            
        except Exception as e:
            if self.config['debug_mode']:
                print(f"정적 예측 오류: {e}")
            return None, 0.0
    
    def predict_dynamic(self):
        """동적 제스처 예측"""
        if not self.tcn_model or len(self.sequence_buffer) < 60:
            return None, 0.0
        
        try:
            # 마지막 60프레임 사용
            sequence = np.array(list(self.sequence_buffer)[-60:])
            sequence_scaled = self.tcn_scaler.transform(sequence)
            sequence_tensor = torch.FloatTensor(sequence_scaled).unsqueeze(0).to(self.device)
            
            with torch.no_grad():
                outputs = self.tcn_model(sequence_tensor)
                probabilities = torch.softmax(outputs, dim=1)
                confidence, predicted = torch.max(probabilities, 1)
                
                predicted_class = predicted.item()
                confidence_score = confidence.item()
            
            return predicted_class, confidence_score
            
        except Exception as e:
            if self.config['debug_mode']:
                print(f"동적 예측 오류: {e}")
            return None, 0.0
    
    def update_and_predict(self):
        """업데이트 및 예측 실행"""
        current_time = time.time()
        
        # 정적 제스처 예측 시도
        if self.should_predict_static():
            prediction, confidence = self.predict_static()
            
            if prediction is not None and confidence >= self.config['static_confidence_threshold']:
                gesture_name = self.mlp_labels.get(prediction, f'static_{prediction}')
                self.set_prediction(prediction, confidence, "static", gesture_name)
                return True
        
        # 동적 제스처 예측 시도
        if self.should_predict_dynamic():
            prediction, confidence = self.predict_dynamic()
            
            if prediction is not None and confidence >= self.config['dynamic_confidence_threshold']:
                gesture_name = self.tcn_labels.get(prediction, f'dynamic_{prediction}')
                self.set_prediction(prediction, confidence, "dynamic", gesture_name)
                return True
        
        return False
    
    def set_prediction(self, prediction, confidence, source, gesture_name):
        """예측 결과 설정"""
        current_time = time.time()
        
        # 예측 결과 설정
        self.last_prediction = prediction
        self.prediction_confidence = confidence
        self.prediction_source = source
        self.last_prediction_time = current_time
        
        # 화면 표시용 (지속적 표시)
        self.display_prediction = prediction
        self.display_confidence = confidence
        self.display_source = source
        self.display_gesture_name = gesture_name
        self.display_time = current_time
        
        # 상태 일부 초기화
        if source == "static":
            self.static_buffer.clear()
        elif source == "dynamic":
            # 동적 제스처 인식 후 상태 완전 초기화
            self.sequence_buffer.clear()  # 시퀀스 버퍼 초기화
            self.movement_start_time = 0
            self.continuous_movement_time = 0
            self.is_moving = False
            self.last_stable_time = current_time
            self.mode = "static"  # Static 모드로 강제 전환
            self.static_start_time = current_time
            # 궤적 완전 초기화
            self.trail_points.clear()
        
        # 예측 결과 출력 (더 상세한 정보 포함)
        source_emoji = "🛑" if source == "static" else "🌀"
        mode_info = f"[{self.mode.upper()}]" if source == "dynamic" else ""
        print(f" {source_emoji} {source.upper()} 인식: {gesture_name.upper()} ({confidence:.1%}) {mode_info}")
        
        # 동적 제스처 인식 시 추가 정보
        if source == "dynamic" and self.config.get('debug_mode', False):
            print(f"    시퀀스 길이: {len(self.sequence_buffer)}/60")
            print(f"    움직임 시간: {self.continuous_movement_time:.1f}초")
            print(f"    안정화 시간: {current_time - self.last_stable_time:.1f}초")
    
    def get_status(self):
        """현재 상태 반환"""
        current_time = time.time()
        
        if self.mode == "dynamic":
            if self.is_moving:
                elapsed = current_time - self.movement_start_time
                return "DYNAMIC_MODE", f"Movement: {elapsed:.1f}s"
            else:
                wait_time = current_time - self.last_stable_time
                return "DYNAMIC_MODE", f"Processing: {wait_time:.1f}s"
        elif self.mode == "static":
            if len(self.static_buffer) > 0:
                held_time = current_time - self.static_start_time
                return "STATIC_MODE", f"Held: {held_time:.1f}s"
            else:
                return "STATIC_MODE", "Ready for gesture"
        else:
            return "MONITORING", "Detecting mode..."


def extract_hand_landmarks(image, hands_detector):
    """손 랜드마크 추출 (test_existing_mlp_live.py와 완전 동일)"""
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands_detector.process(image_rgb)
    
    landmarks = []
    handedness = None
    confidence = 0.0
    finger_tip = None
    
    if results.multi_hand_landmarks and results.multi_handedness:
        # 첫 번째 손만 사용
        hand_landmarks = results.multi_hand_landmarks[0]
        hand_info = results.multi_handedness[0]
        
        # 손 정보 추출
        handedness = hand_info.classification[0].label  # 'Left' or 'Right'
        confidence = hand_info.classification[0].score
        
        # 21개 관절 좌표 추출 (x, y, z, visibility) - test_existing_mlp_live.py와 동일
        joint = np.zeros((21, 4))
        for j, lm in enumerate(hand_landmarks.landmark):
            joint[j] = [lm.x, lm.y, lm.z, lm.visibility]
        
        landmarks = joint
        
        # 검지 끝 좌표 (궤적용) - 8번째 랜드마크
        finger_tip = (joint[8, 0], joint[8, 1])  # x, y 좌표
    
    return landmarks, handedness, confidence, finger_tip

def create_features_from_landmarks(landmarks):
    """랜드마크에서 MLP용 특징 벡터 생성 (test_existing_mlp_live.py와 완전 동일)"""
    if len(landmarks) == 0:
        return None
    
    try:
        # 관절 좌표 (21 x 4 = 84차원) - test_existing_mlp_live.py와 동일
        joint = np.array(landmarks)
        
        # 벡터 계산 (data_collect_improved.py와 동일한 방식)
        v1 = joint[[0,1,2,3,0,5,6,7,0,9,10,11,0,13,14,15,0,17,18,19], :3]
        v2 = joint[[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20], :3]
        v = v2 - v1
        
        # 정규화
        norms = np.linalg.norm(v, axis=1)
        norms[norms == 0] = 1e-6  # 0으로 나누기 방지
        v = v / norms[:, np.newaxis]
        
        # 관절 간 각도 계산
        angle = np.arccos(np.clip(np.einsum('nt,nt->n',
            v[[0,1,2,4,5,6,8,9,10,12,13,14,16,17,18],:],
            v[[1,2,3,5,6,7,9,10,11,13,14,15,17,18,19],:]), -1, 1))
        
        angle = np.degrees(angle)
        
        # 특징 벡터 생성: 관절 위치(84) + 각도(15) = 99차원
        features = np.concatenate([joint.flatten(), angle])
        
        # 유효성 검사
        if np.isnan(features).any() or np.isinf(features).any():
            return None
        
        return features
        
    except Exception as e:
        return None

def create_tcn_features_from_landmarks(landmarks_joint):
    """랜드마크에서 TCN용 특징 벡터 생성 (collect_sequence_data.py와 동일)"""
    if len(landmarks_joint) == 0:
        return None
    
    try:
        # 21개 관절 좌표 (x,y,z)만 추출
        joint = np.array(landmarks_joint)[:, :3]  # (21, 3)
        
        # 기본 좌표에 visibility 추가 (1.0으로 설정)
        joint_with_vis = np.column_stack([joint, np.ones(21)])
        
        # 벡터 계산 (기존 방식과 동일)
        v1 = joint_with_vis[[0,1,2,3,0,5,6,7,0,9,10,11,0,13,14,15,0,17,18,19], :3]
        v2 = joint_with_vis[[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20], :3]
        v = v2 - v1
        
        # 정규화
        norms = np.linalg.norm(v, axis=1)
        norms[norms == 0] = 1e-6
        v = v / norms[:, np.newaxis]
        
        # 관절 간 각도 계산
        angle = np.arccos(np.clip(np.einsum('nt,nt->n',
            v[[0,1,2,4,5,6,8,9,10,12,13,14,16,17,18],:],
            v[[1,2,3,5,6,7,9,10,11,13,14,15,17,18,19],:]), -1, 1))
        
        angle = np.degrees(angle)
        
        # 특징 벡터: 관절(84) + 각도(15) = 99차원
        features = np.concatenate([joint_with_vis.flatten(), angle])
        
        # 유효성 검사
        if np.isnan(features).any() or np.isinf(features).any():
            return None
        
        return features
        
    except Exception as e:
        return None


def draw_landmarks_and_trail(image, landmarks, finger_tip, trail_points, handedness, confidence, mode):
    """손 랜드마크와 궤적 그리기"""
    h, w = image.shape[:2]
    
    if len(landmarks) > 0:
        # 모드에 따른 색상
        if mode == "STATIC_MODE":
            color = COLORS['static_mode']
            hand_text = f"{handedness} Hand (Static)"
        elif mode == "DYNAMIC_MODE":
            color = COLORS['dynamic_mode']  
            hand_text = f"{handedness} Hand (Dynamic)"
        else:
            color = COLORS['waiting']
            hand_text = f"{handedness} Hand"
        
        # 검지 끝 강조
        if finger_tip is not None:
            finger_x = int(finger_tip[0] * w)
            finger_y = int(finger_tip[1] * h)
            cv2.circle(image, (finger_x, finger_y), 8, color, -1)
            cv2.circle(image, (finger_x, finger_y), 12, color, 2)
        
        # 손 정보 표시 (크기 축소)
        cv2.putText(image, f"{hand_text} ({confidence:.2f})", 
                   (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)  # 크기와 두께 축소
    
    # 궤적 그리기
    if INTEGRATED_CONFIG['trail_display'] and len(trail_points) > 1:
        points = [(int(x * w), int(y * h)) for x, y in trail_points]
        for i in range(1, len(points)):
            thickness = max(1, int(3 * (i / len(points))))
            cv2.line(image, points[i-1], points[i], COLORS['trail'], thickness)
    
    return image

def draw_integrated_ui(image, recognizer, fps=None):
    h, w = image.shape[:2]
    
    # 현재 상태 가져오기
    status, status_detail = recognizer.get_status()
    
    # 상태에 따른 색상
    if status == "STATIC_MODE":
        status_color = COLORS['static_mode']
        status_text = " STATIC MODE"
    elif status == "DYNAMIC_MODE":
        status_color = COLORS['dynamic_mode']
        status_text = " DYNAMIC MODE"
    elif status == "MONITORING":
        status_color = COLORS['waiting']
        status_text = " MONITORING"
    else:
        status_color = COLORS['waiting']
        status_text = "⚡ AUTO MODE"
    
    # 인식된 제스처 큰 화면 중앙 표시 (화면 표시용 변수 사용)
    current_time = time.time()
    show_prediction = False
    prediction_text = ""
    pred_color = COLORS['text']
    
    if (recognizer.display_prediction is not None and 
        (current_time - recognizer.display_time) < 3.0 and  # 3초간 표시
        recognizer.display_gesture_name.lower() != 'nothing'):  # nothing은 화면에 표시하지 않음
        
        show_prediction = True
        if recognizer.display_source == "static":
            prediction_text = f"🛑 {recognizer.display_gesture_name.upper()}"
        else:
            prediction_text = f"🌀 {recognizer.display_gesture_name.upper()}"
        
        confidence = recognizer.display_confidence
        if confidence >= 0.8:
            pred_color = COLORS['good']
        elif confidence >= 0.6:
            pred_color = COLORS['medium']
        else:
            pred_color = COLORS['low']
    
    # 큰 제스처 표시 (화면 중앙 상단) - 글씨 크기 축소
    if show_prediction:
        # 배경 박스
        overlay = image.copy()
        text_size = cv2.getTextSize(prediction_text, cv2.FONT_HERSHEY_SIMPLEX, 1.0, 2)[0]  # 크기 축소
        box_w = text_size[0] + 30
        box_h = 60  # 높이 축소
        box_x = (w - box_w) // 2
        box_y = 40  # 위치 조정
        
        cv2.rectangle(overlay, (box_x, box_y), (box_x + box_w, box_y + box_h), COLORS['bg'], -1)
        cv2.addWeighted(overlay, 0.8, image, 0.2, 0, image)
        
        # 제스처 텍스트 
        text_x = box_x + 15
        text_y = box_y + 30
        cv2.putText(image, prediction_text, (text_x, text_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 1.0, pred_color, 2)  # 크기와 두께 축소
        
        # 신뢰도 표시 
        conf_text = f"{recognizer.display_confidence:.1%}"
        cv2.putText(image, conf_text, (text_x, text_y + 20), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, pred_color, 1)  # 크기와 두께 축소
    
    # 하단 상태 정보 박스 
    overlay = image.copy()
    cv2.rectangle(overlay, (10, h-120), (w-10, h-10), COLORS['bg'], -1)  # 높이 축소
    cv2.addWeighted(overlay, 0.7, image, 0.3, 0, image)
    
    # 상태 텍스트 
    cv2.putText(image, status_text, 
               (20, h-90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 1)  # 크기와 두께 축소
    
    # 상태 세부 정보 
    cv2.putText(image, status_detail, 
               (20, h-70), cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['text'], 1)  # 크기 축소
    
    # 최근 인식 결과 
    if show_prediction:
        recent_text = f"Recent: {prediction_text} ({recognizer.display_confidence:.1%})"
        cv2.putText(image, recent_text, 
                   (20, h-50), cv2.FONT_HERSHEY_SIMPLEX, 0.4, pred_color, 1)  # 크기 축소
    
    # 버퍼 정보 
    static_count = len(recognizer.static_buffer)
    dynamic_count = len(recognizer.sequence_buffer)
    buffer_text = f"Buffer: Static({static_count}/10) Dynamic({dynamic_count}/60)"
    cv2.putText(image, buffer_text, 
               (20, h-35), cv2.FONT_HERSHEY_SIMPLEX, 0.35, COLORS['text'], 1)  # 크기 축소
    
    # FPS 표시 
    if fps is not None and INTEGRATED_CONFIG['fps_display']:
        cv2.putText(image, f"FPS: {fps:.1f}", 
                   (w-80, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['text'], 1)  # 크기와 위치 조정
    
    # 제어 가이드 
    cv2.putText(image, "Controls: R-Reset, D-Debug, Q-Quit | Voice: Wake+Command", 
               (20, h-15), cv2.FONT_HERSHEY_SIMPLEX, 0.35, COLORS['text'], 1)  # 크기 축소
    
    return image


class VoiceRecognitionThread(threading.Thread):
    """음성 인식 전용 스레드 """
    
    def __init__(self, colab_url=""):
        super().__init__()
        self.colab_url = colab_url
        self.running = True
        self.daemon = True
        
        # TTS 시스템 초기화
        self.tts_system = TTSSystem()
        
        # 음성 인식 초기화
        self.recognizer = sr.Recognizer()
        self.mic = sr.Microphone()
        
        print(" 음성 인식 스레드 초기화 완료")
    
    def run(self):
        print(" 음성 인식 스레드 시작")
        
        # 초기 지연으로 메인 스레드와 충돌 방지
        time.sleep(2)
        
        if self.tts_system.engine or self.tts_system.use_sapi:
            self.tts_system.speak("음성 제어 시스템이 준비되었습니다", async_mode=False)
        
        while self.running:
            try:
                # 타임아웃 예외 처리 추가
                try:
                    audio = wait_for_wake_word(self.recognizer, self.mic)
                except sr.WaitTimeoutError:
                    # 타임아웃은 정상적인 상황 - 계속 대기
                    continue
                except Exception as e:
                    print(f" 웨이크워드 대기 오류: {e}")
                    time.sleep(1)
                    continue
                
                wav = audio.get_wav_data(convert_rate=16000, convert_width=2)
                with io.BytesIO(wav) as wav_io:
                    with wave.open(wav_io, 'rb') as wav_file:
                        frames = wav_file.readframes(wav_file.getnframes())
                        audio_np = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0

                # Whisper 없이 Google STT로 간단 인식 (웨이크워드 감지용)
                try:
                    text = self.recognizer.recognize_google(audio, language='ko-KR')
                    print(f" 인식됨: {text}")
                except sr.UnknownValueError:
                    print(" 인식 실패 (무음 또는 잡음)")
                    continue
                except sr.RequestError as e:
                    print(f" Google STT 서비스 오류: {e}")
                    continue

                if detect_wake_word(text):
                    print(" 웨이크워드 감지됨 → 명령어 녹음으로 전환")

                    # 웨이크워드 감지 알림음 재생 (TTS보다 먼저)
                    play_beep_sequence()
                    
                    # 웨이크워드 인식 TTS 응답
                    if self.tts_system and (self.tts_system.engine or self.tts_system.use_sapi):
                        self.tts_system.speak("네, 무엇을 도와드릴까요?", async_mode=False)

                    cmd_audio = record_audio()
                    if cmd_audio is None:
                        continue
                    
                    if self.colab_url:
                        result = send_to_colab(cmd_audio, self.colab_url)

                        if "error" in result:
                            print(" 오류:", result["error"])
                            if self.tts_system and (self.tts_system.engine or self.tts_system.use_sapi):
                                self.tts_system.speak("죄송합니다. 오류가 발생했습니다", async_mode=False)
                        else:
                            print("✅ 인식 텍스트:", result["text"])
                            print("🎮 매칭된 명령어:", result["action"])
                            
                            action = result.get("action", "")
                            
                            # 서버에 음성 명령 전송 (새로운 쿨다운 시스템 적용)
                            if action and action in action_to_gesture_map:
                                gesture_command = action_to_gesture_map[action]
                                print(f"\n [음성] 명령어 인식됨: '{result['text']}'")
                                print(f" 제스처 매핑: {action} → {gesture_command}")
                                print(f" 서버 전송을 시작합니다...")
                                
                                # 새로운 쿨다운 시스템으로 전송
                                try_send_voice(gesture_command)
                                
                            # 새로운 명령어 직접 매핑
                            elif action in ['ac_mode', 'ac_power', 'ac_tempDOWN', 'ac_tempUP', 'tv_power', 'tv_channelUP', 'tv_channelDOWN', 'spider_man', 'small_heart', 'thumbs_down', 'thumbs_up', 'thumbs_left', 'thumbs_right']:
                                print(f"\n [음성] 새로운 명령어 인식됨: '{result['text']}'")
                                print(f" 직접 매핑: {action}")
                                print(f" 서버 전송을 시작합니다...")
                                
                                # 새로운 쿨다운 시스템으로 전송
                                try_send_voice(action)
                                
                            elif action:
                                # 매핑되지 않은 액션도 직접 전송
                                print(f"\n [음성] 명령어 인식됨: '{result['text']}'")
                                print(f" 직접 전송: {action}")
                                print(f" 주의: '{action}'은 제스처 매핑에 없습니다.")
                                
                                # 새로운 쿨다운 시스템으로 전송
                                try_send_voice(action)
                                
                            else:
                                print(f" 액션이 비어있거나 인식되지 않았습니다: '{action}'")
                            
                            # TTS로 명령어 실행 결과 출력
                            if self.tts_system and (self.tts_system.engine or self.tts_system.use_sapi):
                                if action:
                                    # 명령어별 TTS 응답 메시지
                                    tts_messages = {
                                        'light_on': '네, 전등을 켜드리겠습니다',
                                        'light_off': '네, 전등을 꺼드리겠습니다',
                                        'ac_on': '네, 에어컨을 켜드리겠습니다',
                                        'ac_off': '네, 에어컨을 꺼드리겠습니다',
                                        'fan_on': '네, 선풍기를 켜드리겠습니다',
                                        'fan_off': '네, 선풍기를 꺼드리겠습니다',
                                        'curtain_open': '네, 커튼을 열어드리겠습니다',
                                        'curtain_close': '네, 커튼을 닫아드리겠습니다',
                                        'tv_on': '네, 티비를 켜드리겠습니다',
                                        'tv_off': '네, 티비를 꺼드리겠습니다',
                                        'temp_up': '네, 온도를 올려드리겠습니다',
                                        'temp_down': '네, 온도를 내려드리겠습니다',
                                        
                                        # 새로운 명령어 TTS 메시지
                                        'ac_mode': '네, 에어컨 모드를 변경하겠습니다',
                                        'ac_power': '네, 에어컨 전원을 조작하겠습니다',
                                        'ac_tempDOWN': '네, 에어컨 온도를 낮추겠습니다',
                                        'ac_tempUP': '네, 에어컨 온도를 높이겠습니다',
                                        'tv_power': '네, TV 전원을 조작하겠습니다',
                                        'tv_channelUP': '네, TV 채널을 올리겠습니다',
                                        'tv_channelDOWN': '네, TV 채널을 내리겠습니다',
                                        'spider_man': '네, 스파이더맨 제스처를 인식했습니다',
                                        'small_heart': '네, 작은 하트 제스처를 인식했습니다',
                                        'thumbs_down': '네, 엄지 다운 제스처를 인식했습니다',
                                        'thumbs_up': '네, 엄지 업 제스처를 인식했습니다',
                                        'thumbs_left': '네, 엄지 왼쪽 제스처를 인식했습니다',
                                        'thumbs_right': '네, 엄지 오른쪽 제스처를 인식했습니다'
                                    }
                                    
                                    tts_msg = tts_messages.get(action, f"명령을 실행했습니다")
                                    self.tts_system.speak(tts_msg, async_mode=False)
                                else:
                                    self.tts_system.speak("명령을 처리했습니다", async_mode=False)
                    else:
                        print(" Colab URL이 설정되지 않았습니다.")

            except KeyboardInterrupt:
                print(" 음성 인식 스레드 종료")
                break
            except Exception as e:
                print(f" 음성 인식 오류: {e}")
                time.sleep(1)
    
    def stop(self):
        """스레드 중지"""
        self.running = False
        if self.tts_system and (self.tts_system.engine or self.tts_system.use_sapi):
            self.tts_system.speak("음성 제어 시스템을 종료합니다", async_mode=False)


def main():
    """메인 통합 함수 (제스처 + 음성)"""
    print(" 통합 제스처 + 음성 인식 시스템")
    print("test_integrated_gesture_live.py + voice_recognition.py")
    print("=" * 60)
    
    # 음성 인식 설정
    colab_url = input("Colab ngrok URL을 입력하세요 (선택사항, Enter로 건너뛰기): ").strip()
    if not colab_url:
        print(" Colab URL 없이 진행합니다. 음성 인식은 제한적으로 작동합니다.")
    
    # 통합 인식기 초기화 (test_integrated_gesture_live.py와 동일)
    recognizer = IntegratedGestureRecognizer(INTEGRATED_CONFIG)
    
    if not recognizer.mlp_model and not recognizer.tcn_model:
        print(" MLP와 TCN 모델 모두 로딩에 실패했습니다.")
        return
    
    if not recognizer.mlp_model:
        print(" MLP 모델이 없습니다. 동적 제스처만 인식됩니다.")
    
    if not recognizer.tcn_model:
        print(" TCN 모델이 없습니다. 정적 제스처만 인식됩니다.")
    
    # MediaPipe 초기화 (test_integrated_gesture_live.py와 동일)
    print(" MediaPipe 초기화 중...")
    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=INTEGRATED_CONFIG['min_detection_confidence'],
        min_tracking_confidence=INTEGRATED_CONFIG['min_tracking_confidence']
    )
    
    # 웹캠 초기화
    print(" 웹캠 초기화 중...")
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print(" 웹캠을 열 수 없습니다.")
        return
    
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)
    
    # 음성 인식 스레드 시작
    print(" 음성 인식 스레드 초기화 중...")
    voice_thread = VoiceRecognitionThread(colab_url)
    voice_thread.start()
    
    print(" 초기화 완료!")
    print("\n 통합 실시간 인식 시작!")
    print(" 유연한 인식 방식:")
    print("    정적 제스처: 기본 모드 - 손을 1초간 유지하면 즉시 인식")
    print("    동적 제스처: 0.5초 이상 움직임 → 1초 후 인식 (손이 화면에 있어도 OK!)")
    print("    음성 명령: '브릿지' + 명령어로 IoT 제어")
    if SOUND_AVAILABLE:
        print("    웨이크워드 알림: '띠-링-롱' 멜로디 재생")
    else:
        print("    웨이크워드 알림: 사운드 없음 (winsound 모듈 필요)")
    print("    움직임 임계값: 0.04 (더 민감함 - 시계방향 회전도 감지)")
    print("    빠른 반응: 3-8프레임 윈도우로 즉시 감지")
    print("   R - 상태 리셋")
    print("   D - 디버그 모드 토글")
    print("   Q - 종료")
    print("=" * 60)
    print(" 손을 카메라에 대고 제스처를 수행하거나 '브릿지' 음성 명령을 말하세요!")
    if SOUND_AVAILABLE:
        print(" 웨이크워드 '스마트 브릿지' 인식 시 알림음이 재생됩니다!")
    
    fps_counter = deque(maxlen=30)
    frame_count = 0
    
    try:
        while True:
            start_time = time.time()
            
            ret, frame = cap.read()
            if not ret:
                print(" 프레임을 읽을 수 없습니다.")
                break
            
            frame = cv2.flip(frame, 1)
            frame_count += 1
            
            # 손 랜드마크 추출 (test_integrated_gesture_live.py와 동일)
            landmarks, handedness, hand_confidence, finger_tip = extract_hand_landmarks(frame, hands)
            
            # 인식 시스템 업데이트 (test_integrated_gesture_live.py와 동일)
            hand_detected = len(landmarks) > 0 and hand_confidence >= INTEGRATED_CONFIG['min_detection_confidence']
            
            if hand_detected:
                # MLP용 특징 추출 (test_existing_mlp_live.py와 동일)
                mlp_features = create_features_from_landmarks(landmarks)
                
                # TCN용 특징 추출 (collect_sequence_data.py와 동일)
                tcn_features = create_tcn_features_from_landmarks(landmarks)
                
                # 인식기에 두 가지 특징 모두 전달
                recognizer.add_frame(mlp_features, tcn_features, finger_tip, hand_detected=True)
                
                # 현재 상태 가져오기
                status, _ = recognizer.get_status()
                
                # 손과 궤적 그리기
                frame = draw_landmarks_and_trail(
                    frame, landmarks, finger_tip, recognizer.trail_points, 
                    handedness, hand_confidence, status
                )
            else:
                recognizer.add_frame(None, None, None, hand_detected=False)
            
            # 예측 시도 (test_integrated_gesture_live.py와 동일)
            recognizer.update_and_predict()
            
            # 제스처 결과 서버 전송 (새로운 쿨다운 시스템 적용)
            if recognizer.last_prediction is not None:
                gesture_name = ""
                if recognizer.prediction_source == "static":
                    gesture_name = recognizer.mlp_labels.get(recognizer.last_prediction, f'static_{recognizer.last_prediction}')
                else:
                    gesture_name = recognizer.tcn_labels.get(recognizer.last_prediction, f'dynamic_{recognizer.last_prediction}')
                
                print(f" [손동작] 제스처 인식: {gesture_name} ({recognizer.prediction_source.upper()})")
                print(f" 인식 시간: {time.strftime('%H:%M:%S')}")
                
                # nothing 제스처는 서버로 전송하지 않음
                if gesture_name.lower() != 'nothing':
                    # 새로운 쿨다운 시스템으로 전송
                    try_send_gesture(gesture_name)
                else:
                    print(" nothing 제스처는 서버로 전송하지 않습니다.")
                
                # 전송 후 예측 결과 완전 초기화
                recognizer.last_prediction = None
                recognizer.prediction_confidence = 0.0
                recognizer.prediction_source = ""
            
            # FPS 계산 (test_integrated_gesture_live.py와 동일)
            end_time = time.time()
            fps = 1.0 / (end_time - start_time)
            fps_counter.append(fps)
            avg_fps = np.mean(fps_counter)
            
            # UI 그리기 (test_integrated_gesture_live.py와 동일)
            frame = draw_integrated_ui(frame, recognizer, avg_fps)
            
            # 화면 표시
            cv2.imshow('Unified Gesture + Voice Recognition System', frame)
            
            # 키 입력 처리 (test_integrated_gesture_live.py와 동일)
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('q'):
                print("\n 사용자가 종료를 요청했습니다.")
                break
            elif key == ord('r'):
                recognizer.reset_state()
                print(" 상태 리셋")
            elif key == ord('d'):
                INTEGRATED_CONFIG['debug_mode'] = not INTEGRATED_CONFIG['debug_mode']
                print(f" 디버그 모드: {'ON' if INTEGRATED_CONFIG['debug_mode'] else 'OFF'}")
    
    except KeyboardInterrupt:
        print("\n 인터럽트로 종료됩니다.")
    
    except Exception as e:
        print(f"\n 오류 발생: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # 정리
        voice_thread.stop()
        voice_thread.join(timeout=3)
        cap.release()
        cv2.destroyAllWindows()
        hands.close()
        
        print("\n 세션 통계:")
        if len(fps_counter) > 0:
            print(f"   - 평균 FPS: {np.mean(fps_counter):.1f}")
        print(f"   - 총 프레임: {frame_count:,}")
        print("\n 통합 인식 테스트 완료!")

if __name__ == "__main__":
    main()
