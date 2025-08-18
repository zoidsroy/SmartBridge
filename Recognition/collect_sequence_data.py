# collect_sequence_data.py
"""
시퀀스 제스처 데이터 수집 (TCN용)
시계방향, 반시계방향, 별 모양 등 동적 제스처 수집

Author: AIoT Project Team
Date: 2024
"""

import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
import os
import time
import json
from datetime import datetime
from collections import deque
# import keyboard  # 사용하지 않음

# =============================================================================
# 설정 및 상수
# =============================================================================

# 동적 제스처 설정 (사용자가 직접 입력)
SEQUENCE_GESTURES = {}  # 빈 딕셔너리로 시작
GESTURE_NAMES = []      # 빈 리스트로 시작
LABEL_TO_NAME = {}      # 빈 딕셔너리로 시작

# 데이터 수집 설정
COLLECTION_CONFIG = {
    'sequence_length': 60,           # 시퀀스 길이 (프레임 수)
    'fps': 30,                       # 목표 FPS
    'samples_per_gesture': 200,      # 제스처당 샘플 수
    'min_confidence': 0.7,           # 최소 감지 신뢰도
    'gesture_duration': 2.5,         # 제스처 수행 시간 (초)
    'rest_duration': 1.0,            # 제스처 간 휴식 시간 (초)
    'auto_save_interval': 20,        # 자동 저장 간격
    'data_dir': './gesture_data/sequence_data',
    'show_guidelines': True,         # 가이드라인 표시
    'quality_check': True,           # 데이터 품질 검사
}

# MediaPipe 설정
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils

# 색상 설정 (BGR)
COLORS = {
    'good': (0, 255, 0),      # 초록색 (수집 중)
    'waiting': (0, 255, 255),  # 노란색 (대기)
    'rest': (255, 0, 0),      # 파란색 (휴식)
    'complete': (255, 0, 255), # 마젠타 (완료)
    'text': (255, 255, 255),   # 흰색
    'bg': (50, 50, 50),        # 회색
    'trail': (0, 165, 255),    # 주황색 (궤적)
}

# =============================================================================
# 데이터 수집 클래스
# =============================================================================

class SequenceGestureCollector:
    """시퀀스 제스처 데이터 수집기"""
    
    def __init__(self, config):
        self.config = config
        self.current_gesture_name = None
        self.current_sample = 0
        self.collected_data = []
        self.gesture_names = []  # 수집된 제스처 이름들
        
        # 수집 상태
        self.collecting = False
        self.in_rest = False
        self.sequence_buffer = deque(maxlen=config['sequence_length'])
        self.trail_points = deque(maxlen=30)  # 궤적 표시용
        
        # 타이밍
        self.gesture_start_time = 0
        self.rest_start_time = 0
        
        # MediaPipe 초기화
        self.hands = mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=config['min_confidence'],
            min_tracking_confidence=0.5
        )
        
        # 저장 디렉토리 생성
        os.makedirs(config['data_dir'], exist_ok=True)
        
        # 메타데이터 초기화
        self.metadata = {
            'collection_start': datetime.now().isoformat(),
            'config': config,
            'gestures': {},  # 동적으로 채워질 예정
            'collected_samples': {}  # 동적으로 채워질 예정
        }
        
        print("🎯 시퀀스 제스처 데이터 수집기 초기화 완료!")
        print(f"📁 저장 경로: {config['data_dir']}")
        print(f"💡 새로운 제스처 이름을 입력하여 수집을 시작하세요!")
    
    def extract_hand_landmarks(self, image):
        """손 랜드마크 추출"""
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.hands.process(image_rgb)
        
        landmarks = []
        handedness = None
        confidence = 0.0
        
        if results.multi_hand_landmarks and results.multi_handedness:
            hand_landmarks = results.multi_hand_landmarks[0]
            hand_info = results.multi_handedness[0]
            
            handedness = hand_info.classification[0].label
            confidence = hand_info.classification[0].score
            
            # 랜드마크 추출
            for lm in hand_landmarks.landmark:
                landmarks.extend([lm.x, lm.y, lm.z])
            
            # 궤적 포인트 추가 (검지 끝)
            if len(landmarks) >= 24:  # 8번 랜드마크 (검지 끝)
                finger_tip = (landmarks[24], landmarks[25])  # x, y
                self.trail_points.append(finger_tip)
        
        return landmarks, handedness, confidence
    
    def create_features_from_landmarks(self, landmarks):
        """랜드마크에서 특징 벡터 생성 (기존 방식과 동일)"""
        if len(landmarks) < 63:  # 21 * 3
            return None
        
        try:
            # 21개 관절 좌표 재구성
            joint = np.array(landmarks).reshape(21, 3)
            
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
            print(f"특징 추출 오류: {e}")
            return None
    
    def update_collection_state(self):
        """수집 상태 업데이트"""
        current_time = time.time()
        
        if self.collecting:
            # 제스처 수집 중
            elapsed = current_time - self.gesture_start_time
            if elapsed >= self.config['gesture_duration']:
                # 제스처 완료
                self.complete_current_gesture()
                self.start_rest_period()
        
        elif self.in_rest:
            # 휴식 중
            elapsed = current_time - self.rest_start_time
            if elapsed >= self.config['rest_duration']:
                # 휴식 완료
                self.in_rest = False
                print(f"\n✅ 휴식 완료! 다음 샘플 준비")
    
    def set_current_gesture(self, gesture_name):
        """현재 수집할 제스처 설정"""
        self.current_gesture_name = gesture_name
        
        # 새로운 제스처인 경우 추가
        if gesture_name not in self.gesture_names:
            self.gesture_names.append(gesture_name)
            self.metadata['collected_samples'][gesture_name] = 0
            print(f"✅ 새로운 제스처 '{gesture_name}' 추가됨")
        
        # 해당 제스처의 현재 샘플 수 확인
        self.current_sample = self.metadata['collected_samples'][gesture_name]
        print(f"📊 '{gesture_name}' 현재 샘플 수: {self.current_sample}")
    
    def start_collecting(self):
        """제스처 수집 시작"""
        if self.current_gesture_name is None:
            print("❌ 제스처 이름이 설정되지 않았습니다. 먼저 제스처를 입력해주세요.")
            return False
            
        if not self.collecting and not self.in_rest:
            self.collecting = True
            self.gesture_start_time = time.time()
            self.sequence_buffer.clear()
            self.trail_points.clear()
            
            sample_num = self.current_sample + 1
            total_samples = self.config['samples_per_gesture']
            
            print(f"\n🎯 수집 시작: {self.current_gesture_name} ({sample_num}/{total_samples})")
            print(f"⏱️ {self.config['gesture_duration']}초 동안 제스처를 수행하세요!")
            return True
        
        return False
    
    def complete_current_gesture(self):
        """현재 제스처 수집 완료"""
        if len(self.sequence_buffer) >= self.config['sequence_length']:
            # 시퀀스 데이터 저장 (라벨은 -1로 설정, 나중에 할당)
            sequence_data = {
                'gesture': self.current_gesture_name,
                'label': -1,  # 나중에 할당
                'sample_id': self.current_sample,
                'timestamp': datetime.now().isoformat(),
                'sequence': [feature.tolist() if hasattr(feature, 'tolist') else feature 
                           for feature in self.sequence_buffer],  # numpy array → list 변환
                'sequence_length': len(self.sequence_buffer)
            }
            
            self.collected_data.append(sequence_data)
            self.metadata['collected_samples'][self.current_gesture_name] += 1
            
            print(f"✅ 수집 완료: {self.current_gesture_name} 샘플 {self.current_sample + 1}")
            
            # 다음 샘플로 이동
            self.current_sample += 1
            
            # 자동 저장
            if self.current_sample % self.config['auto_save_interval'] == 0:
                self.save_data()
            
            # 제스처 완료 체크
            if self.current_sample >= self.config['samples_per_gesture']:
                print(f"\n🎉 '{self.current_gesture_name}' 수집 완료! ({self.config['samples_per_gesture']}개)")
                print("새로운 제스처를 입력하거나 'Q'를 눌러 종료하세요.")
                self.current_gesture_name = None  # 제스처 초기화
        
        self.collecting = False
    
    def start_rest_period(self):
        """휴식 기간 시작"""
        self.in_rest = True
        self.rest_start_time = time.time()
        print(f"😴 휴식 시간: {self.config['rest_duration']}초")
    
    def get_gesture_input(self):
        """사용자로부터 제스처 이름 입력받기"""
        while True:
            try:
                gesture_name = input("\n🎯 수집할 제스처 이름을 입력하세요 (종료: 'quit' 또는 'q'): ").strip()
                
                if gesture_name.lower() in ['quit', 'q', 'exit']:
                    return None
                
                if len(gesture_name) == 0:
                    print("❌ 제스처 이름을 입력해주세요.")
                    continue
                
                # 특수문자 제거 및 공백을 언더스코어로 변환
                clean_name = gesture_name.replace(' ', '_').replace('-', '_')
                clean_name = ''.join(c for c in clean_name if c.isalnum() or c == '_')
                
                if len(clean_name) == 0:
                    print("❌ 유효한 제스처 이름을 입력해주세요 (알파벳, 숫자, 언더스코어만 사용).")
                    continue
                
                return clean_name
                
            except KeyboardInterrupt:
                return None
            except Exception as e:
                print(f"❌ 입력 오류: {e}")
                continue
    
    def save_data(self):
        """중간 저장"""
        if not self.collected_data:
            return
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"sequence_data_temp_{timestamp}.json"
        filepath = os.path.join(self.config['data_dir'], filename)
        
        save_data = {
            'metadata': self.metadata,
            'data': self.collected_data
        }
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(save_data, f, indent=2, ensure_ascii=False)
        
        print(f"💾 중간 저장: {filename}")
    
    def save_final_data(self):
        """최종 데이터 저장"""
        if not self.collected_data:
            print("❌ 저장할 데이터가 없습니다.")
            return
        
        # JSON 형태로 저장
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        json_filename = f"sequence_gestures_{timestamp}.json"
        json_filepath = os.path.join(self.config['data_dir'], json_filename)
        
        # 메타데이터 업데이트
        self.metadata['collection_end'] = datetime.now().isoformat()
        self.metadata['total_samples'] = len(self.collected_data)
        
        save_data = {
            'metadata': self.metadata,
            'data': self.collected_data
        }
        
        with open(json_filepath, 'w', encoding='utf-8') as f:
            json.dump(save_data, f, indent=2, ensure_ascii=False)
        
        # NumPy 형태로도 저장 (학습용)
        self.save_numpy_format(timestamp)
        
        print(f"\n🎉 최종 저장 완료!")
        print(f"   📁 JSON: {json_filename}")
        print(f"   📁 NumPy: sequence_gestures_{timestamp}.npz")
        print(f"   📊 총 샘플: {len(self.collected_data)}개")
        
        # 통계 출력
        self.print_collection_stats()
    
    def save_numpy_format(self, timestamp):
        """NumPy 형태로 저장 (TCN 학습용) - 라벨은 나중에 할당"""
        sequences = []
        gesture_names = []
        
        # 제스처 이름을 라벨로 매핑할 딕셔너리 생성
        unique_gestures = list(set([data['gesture'] for data in self.collected_data]))
        gesture_to_label = {gesture: idx for idx, gesture in enumerate(unique_gestures)}
        
        for data in self.collected_data:
            # 이미 list로 변환된 sequence를 numpy array로 변환
            sequence_list = data['sequence']
            if isinstance(sequence_list[0], list):
                # 중첩 리스트인 경우 numpy array로 변환
                sequence = np.array(sequence_list)
            else:
                # 이미 numpy array이거나 단순 리스트인 경우
                sequence = np.array(sequence_list)
            
            gesture_name = data['gesture']
            
            # 시퀀스 길이 맞추기
            if len(sequence) == self.config['sequence_length']:
                sequences.append(sequence)
                gesture_names.append(gesture_name)
        
        if sequences:
            sequences = np.array(sequences)  # (N, seq_len, features)
            
            numpy_filename = f"sequence_gestures_{timestamp}.npz"
            numpy_filepath = os.path.join(self.config['data_dir'], numpy_filename)
            
            np.savez_compressed(
                numpy_filepath,
                sequences=sequences,
                gesture_names=np.array(gesture_names),  # 각 샘플의 제스처 이름
                unique_gestures=unique_gestures,        # 유니크한 제스처 목록
                gesture_to_label=gesture_to_label,      # 제스처 -> 라벨 매핑
                config=self.config
            )
            
            print(f"   📋 수집된 제스처: {unique_gestures}")
            print(f"   🏷️ 라벨 매핑: {gesture_to_label}")
    
    def print_collection_stats(self):
        """수집 통계 출력"""
        print(f"\n📊 수집 통계:")
        print("-" * 40)
        
        total_samples = 0
        for gesture_name in self.gesture_names:
            count = self.metadata['collected_samples'][gesture_name]
            total_samples += count
            percentage = (count / self.config['samples_per_gesture']) * 100
            print(f"   {gesture_name:15s}: {count:3d} ({percentage:5.1f}%)")
        
        print("-" * 40)
        print(f"   총 샘플: {total_samples}")
        print(f"   수집된 제스처 수: {len(self.gesture_names)}")
        
        if total_samples > 0:
            avg_sequence_len = np.mean([len(data['sequence']) for data in self.collected_data])
            print(f"   평균 시퀀스 길이: {avg_sequence_len:.1f}")
    
    def draw_ui(self, image):
        """UI 그리기"""
        h, w = image.shape[:2]
        
        # 현재 상태에 따른 색상
        if self.collecting:
            status_color = COLORS['good']
            status_text = "COLLECTING"
        elif self.in_rest:
            status_color = COLORS['rest']
            status_text = "RESTING"
        else:
            status_color = COLORS['waiting']
            status_text = "READY"
        
        # 배경 박스
        overlay = image.copy()
        cv2.rectangle(overlay, (10, 10), (w-10, 120), COLORS['bg'], -1)
        cv2.addWeighted(overlay, 0.7, image, 0.3, 0, image)
        
        # 제스처 정보
        if self.current_gesture_name:
            gesture_name = self.current_gesture_name
            progress = f"{self.current_sample}/{self.config['samples_per_gesture']}"
            
            cv2.putText(image, f"Gesture: {gesture_name.upper()}", 
                       (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, COLORS['text'], 2)
            cv2.putText(image, f"Progress: {progress}", 
                       (20, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['text'], 1)
        else:
            cv2.putText(image, "Gesture: NOT SET", 
                       (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, COLORS['no_hand'], 2)
            cv2.putText(image, "Enter gesture name first", 
                       (20, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['text'], 1)
        
        cv2.putText(image, f"Status: {status_text}", 
                   (20, 85), cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 2)
        
        # 타이머
        if self.collecting:
            elapsed = time.time() - self.gesture_start_time
            remaining = max(0, self.config['gesture_duration'] - elapsed)
            cv2.putText(image, f"Time: {remaining:.1f}s", 
                       (w-150, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, status_color, 2)
        elif self.in_rest:
            elapsed = time.time() - self.rest_start_time
            remaining = max(0, self.config['rest_duration'] - elapsed)
            cv2.putText(image, f"Rest: {remaining:.1f}s", 
                       (w-150, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, status_color, 2)
        
        # 궤적 그리기
        if len(self.trail_points) > 1:
            points = [(int(x * w), int(y * h)) for x, y in self.trail_points]
            for i in range(1, len(points)):
                cv2.line(image, points[i-1], points[i], COLORS['trail'], 3)
        
        # 가이드라인
        if self.config['show_guidelines'] and self.current_gesture_name:
            self.draw_guidelines(image, self.current_gesture_name)
        
        # 제어 가이드
        cv2.putText(image, "Controls: SPACE-Start, N-New Gesture, Q-Quit", 
                   (20, h-20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['text'], 1)
        
        return image
    
    def draw_guidelines(self, image, gesture_name):
        """제스처별 가이드라인 그리기"""
        h, w = image.shape[:2]
        center_x, center_y = w // 2, h // 2
        radius = min(w, h) // 4
        
        # 반투명 오버레이
        overlay = image.copy()
        
        if gesture_name in ['clockwise', 'counter_clockwise']:
            # 원형 가이드
            cv2.circle(overlay, (center_x, center_y), radius, COLORS['trail'], 2)
            # 방향 화살표
            if gesture_name == 'clockwise':
                cv2.arrowedLine(overlay, (center_x + radius//2, center_y - radius//2),
                              (center_x + radius//2, center_y + radius//2), COLORS['trail'], 3)
            else:
                cv2.arrowedLine(overlay, (center_x + radius//2, center_y + radius//2),
                              (center_x + radius//2, center_y - radius//2), COLORS['trail'], 3)
        
        elif gesture_name == 'star':
            # 별 모양 가이드
            points = []
            for i in range(10):
                angle = i * np.pi / 5
                if i % 2 == 0:
                    r = radius
                else:
                    r = radius // 2
                x = int(center_x + r * np.cos(angle - np.pi/2))
                y = int(center_y + r * np.sin(angle - np.pi/2))
                points.append((x, y))
            
            for i in range(len(points)):
                cv2.line(overlay, points[i], points[(i+1) % len(points)], COLORS['trail'], 2)
        
        elif gesture_name == 'triangle':
            # 삼각형 가이드
            points = [
                (center_x, center_y - radius),
                (center_x - radius//2, center_y + radius//2),
                (center_x + radius//2, center_y + radius//2),
                (center_x, center_y - radius)
            ]
            for i in range(len(points)-1):
                cv2.line(overlay, points[i], points[i+1], COLORS['trail'], 2)
        
        elif gesture_name == 'square':
            # 사각형 가이드
            top_left = (center_x - radius//2, center_y - radius//2)
            bottom_right = (center_x + radius//2, center_y + radius//2)
            cv2.rectangle(overlay, top_left, bottom_right, COLORS['trail'], 2)
        
        # 오버레이 적용
        cv2.addWeighted(overlay, 0.3, image, 0.7, 0, image)

# =============================================================================
# 메인 수집 함수
# =============================================================================

def main():
    """메인 데이터 수집 함수"""
    print("🎯 시퀀스 제스처 데이터 수집 (TCN용)")
    print("=" * 60)
    
    # 수집기 초기화
    collector = SequenceGestureCollector(COLLECTION_CONFIG)
    
    # 웹캠 초기화
    print("📹 웹캠 초기화 중...")
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("❌ 웹캠을 열 수 없습니다.")
        return
    
    # 해상도 및 FPS 설정
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, COLLECTION_CONFIG['fps'])
    
    print("✅ 초기화 완료!")
    print("\n🎯 수집 시작!")
    print("🔧 제어:")
    print("   N - 새로운 제스처 입력")
    print("   SPACE - 제스처 수집 시작")
    print("   Q - 종료")
    print("=" * 60)
    
    # 첫 번째 제스처 입력 받기
    print("\n💡 먼저 수집할 제스처 이름을 입력해주세요!")
    gesture_name = collector.get_gesture_input()
    
    if gesture_name is None:
        print("👋 수집을 종료합니다.")
        cap.release()
        cv2.destroyAllWindows()
        collector.hands.close()
        return
    
    collector.set_current_gesture(gesture_name)
    print("Space 키를 눌러서 수집을 시작하세요!")
    
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("❌ 프레임을 읽을 수 없습니다.")
                break
            
            frame = cv2.flip(frame, 1)  # 좌우 반전
            
            # 상태 업데이트
            collector.update_collection_state()
            
            # 손 랜드마크 추출
            landmarks, handedness, confidence = collector.extract_hand_landmarks(frame)
            
            # 수집 중인 경우 데이터 추가
            if collector.collecting and len(landmarks) > 0 and confidence >= COLLECTION_CONFIG['min_confidence']:
                features = collector.create_features_from_landmarks(landmarks)
                if features is not None:
                    collector.sequence_buffer.append(features)
            
            # 손 그리기
            if len(landmarks) > 0:
                # 랜드마크를 다시 MediaPipe 형태로 변환해서 그리기
                # 간단하게 검지 끝점만 표시
                h, w = frame.shape[:2]
                if len(landmarks) >= 24:
                    finger_x = int(landmarks[24] * w)
                    finger_y = int(landmarks[25] * h)
                    cv2.circle(frame, (finger_x, finger_y), 8, COLORS['good'], -1)
            
            # UI 그리기
            frame = collector.draw_ui(frame)
            
            # 화면 표시
            cv2.imshow('Sequence Gesture Collection', frame)
            
            # 키 입력 처리
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('q'):
                print("\n👋 사용자가 종료를 요청했습니다.")
                break
            elif key == ord(' '):
                collector.start_collecting()
            elif key == ord('n'):
                print("\n🔄 새로운 제스처 입력...")
                new_gesture = collector.get_gesture_input()
                if new_gesture is None:
                    print("❌ 제스처 입력이 취소되었습니다.")
                else:
                    collector.set_current_gesture(new_gesture)
                    print("Space 키를 눌러서 수집을 시작하세요!")
    
    except KeyboardInterrupt:
        print("\n⏹️ 인터럽트로 종료됩니다.")
    
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # 정리
        cap.release()
        cv2.destroyAllWindows()
        collector.hands.close()
        
        # 최종 저장
        if collector.collected_data:
            collector.save_final_data()
        
        print("\n🎉 데이터 수집 완료!")

if __name__ == "__main__":
    main()