# merge_MLP_data.py
"""
기존 수집된 데이터를 MLP 학습용으로 병합하는 스크립트
./gesture_data/main_data/large_data의 CSV 파일들을 통합

Author: AIoT Project Team
"""

import pandas as pd
import numpy as np
import os
import glob
from collections import Counter
import json
from datetime import datetime

# =============================================================================
# 설정 및 제스처 매핑
# =============================================================================

# 제스처 라벨 매핑 (16개 클래스)
GESTURE_LABELS = {
    'four': 0, 'horizontal_V': 1, 'ok': 2, 'one': 3, 'promise': 4,
    'small_heart': 5, 'spider_man': 6, 'three': 7, 'three2': 8, 
    'thumbs_down': 9, 'thumbs_left': 10, 'thumbs_right': 11, 
    'thumbs_up': 12, 'two': 13, 'vertical_V': 14, 'nothing': 15
}

LABEL_TO_NAME = {v: k for k, v in GESTURE_LABELS.items()}

# 경로 설정
SOURCE_DIR = './gesture_data/main_data/large_data'
OUTPUT_FILE = './gesture_data/merged_existing_data_16.npy'
METADATA_FILE = './gesture_data/merged_data_metadata_16.json'

# =============================================================================
# 유틸리티 함수들
# =============================================================================

def extract_gesture_from_filename(filename):
    """파일명에서 제스처 이름 추출"""
    # 파일명 패턴: data_[gesture_name]_[number].csv
    basename = os.path.basename(filename)
    if not basename.startswith('data_'):
        return None
    
    # 'data_' 제거하고 마지막 '_숫자.csv' 제거
    name_part = basename[5:]  # 'data_' 제거
    
    # 마지막 '_숫자.csv' 패턴 제거
    parts = name_part.split('_')
    if len(parts) >= 2:
        # 마지막 부분이 숫자.csv 형태인지 확인
        last_part = parts[-1]
        if last_part.replace('.csv', '').isdigit():
            gesture_name = '_'.join(parts[:-1])
        else:
            gesture_name = name_part.replace('.csv', '')
    else:
        gesture_name = name_part.replace('.csv', '')
    
    return gesture_name if gesture_name in GESTURE_LABELS else None

def validate_csv_data(df, filename):
    """CSV 데이터 검증"""
    if df.empty:
        print(f"   ❌ 빈 파일: {filename}")
        return False
    
    if df.shape[1] != 100:
        print(f"   ❌ 잘못된 열 수: {filename} - {df.shape[1]} (예상: 100)")
        return False
    
    # 첫 번째 행이 헤더인지 확인 (0,1,2,3... 패턴)
    first_row = df.iloc[0].values
    is_header = all(str(first_row[i]).replace('.0', '') == str(i) for i in range(min(10, len(first_row))))
    
    return True, is_header

def clean_data(df, has_header=True):
    """데이터 정리"""
    # 헤더 제거
    if has_header:
        df = df.iloc[1:].reset_index(drop=True)
    
    # 빈 행 제거
    df = df.dropna().reset_index(drop=True)
    
    # 특징과 라벨 분리
    features = df.iloc[:, :-1].values.astype(np.float32)  # 99차원 특징
    raw_labels = df.iloc[:, -1].values  # 라벨
    
    return features, raw_labels

# =============================================================================
# 메인 병합 함수
# =============================================================================

def merge_existing_data():
    """기존 데이터 병합"""
    print("🔄 기존 수집 데이터 병합 시작...")
    print("=" * 60)
    
    # 소스 디렉토리 확인
    if not os.path.exists(SOURCE_DIR):
        print(f"❌ 소스 디렉토리를 찾을 수 없습니다: {SOURCE_DIR}")
        return False
    
    # CSV 파일들 찾기
    csv_files = glob.glob(os.path.join(SOURCE_DIR, "data_*.csv"))
    
    if not csv_files:
        print(f"❌ CSV 파일을 찾을 수 없습니다: {SOURCE_DIR}")
        return False
    
    print(f"📊 발견된 파일: {len(csv_files)}개")
    
    # 제스처별 데이터 수집
    all_features = []
    all_labels = []
    gesture_stats = Counter()
    file_stats = []
    processed_files = 0
    skipped_files = 0
    
    for file_path in sorted(csv_files):
        print(f"\n📁 처리 중: {os.path.basename(file_path)}")
        
        # 제스처 이름 추출
        gesture_name = extract_gesture_from_filename(file_path)
        
        if gesture_name is None:
            print(f"   ⚠️ 건너뜀 (알 수 없는 제스처): {os.path.basename(file_path)}")
            skipped_files += 1
            continue
        
        try:
            # CSV 로딩
            df = pd.read_csv(file_path, header=None)
            
            # 데이터 검증
            validation_result = validate_csv_data(df, os.path.basename(file_path))
            if validation_result is False:
                skipped_files += 1
                continue
            
            is_valid, has_header = validation_result
            
            # 데이터 정리
            features, raw_labels = clean_data(df, has_header)
            
            if len(features) == 0:
                print(f"   ❌ 유효한 데이터 없음")
                skipped_files += 1
                continue
            
            # 라벨을 숫자로 변환
            gesture_label = GESTURE_LABELS[gesture_name]
            labels = np.full(len(features), gesture_label, dtype=int)
            
            # 데이터 추가
            all_features.append(features)
            all_labels.append(labels)
            gesture_stats[gesture_name] += len(features)
            
            # 파일 통계
            file_stats.append({
                'file': os.path.basename(file_path),
                'gesture': gesture_name,
                'label': gesture_label,
                'samples': len(features),
                'size_mb': os.path.getsize(file_path) / (1024 * 1024)
            })
            
            print(f"   ✅ 성공: {len(features):,} 샘플 ({gesture_name} → {gesture_label})")
            processed_files += 1
            
        except Exception as e:
            print(f"   ❌ 오류: {e}")
            skipped_files += 1
    
    print(f"\n📊 파일 처리 결과:")
    print(f"   - 처리됨: {processed_files}개")
    print(f"   - 건너뜀: {skipped_files}개")
    
    if not all_features:
        print("❌ 처리된 데이터가 없습니다.")
        return False
    
    # 데이터 병합
    print(f"\n🔗 데이터 병합 중...")
    combined_features = np.vstack(all_features)
    combined_labels = np.hstack(all_labels)
    
    print(f"   - 총 샘플: {len(combined_features):,}")
    print(f"   - 특징 차원: {combined_features.shape[1]}")
    print(f"   - 라벨 범위: {combined_labels.min()} ~ {combined_labels.max()}")
    
    # 제스처별 분포 확인
    print(f"\n📊 제스처별 데이터 분포:")
    total_samples = len(combined_features)
    for gesture_name in sorted(GESTURE_LABELS.keys()):
        label = GESTURE_LABELS[gesture_name]
        count = gesture_stats.get(gesture_name, 0)
        percentage = count / total_samples * 100 if total_samples > 0 else 0
        
        if count > 0:
            status = "✅"
        else:
            status = "❌ 누락"
        
        print(f"   {label:2d} {gesture_name:12s}: {count:6,} ({percentage:5.1f}%) {status}")
    
    # 데이터 품질 확인 (메모리 효율적으로)
    print(f"\n🔍 데이터 품질 확인:")
    print(f"   - 특징 범위: [{combined_features.min():.3f}, {combined_features.max():.3f}]")
    print(f"   - 평균: {combined_features.mean():.3f}")
    
    # 메모리 효율적인 표준편차 계산
    try:
        # 배치 단위로 계산하여 메모리 사용량 줄이기
        batch_size = 100000
        total_sum = 0
        total_count = 0
        
        for i in range(0, len(combined_features), batch_size):
            batch = combined_features[i:i+batch_size]
            batch_mean = batch.mean()
            batch_var = ((batch - batch_mean) ** 2).mean()
            total_sum += batch_var * len(batch)
            total_count += len(batch)
        
        overall_std = np.sqrt(total_sum / total_count)
        print(f"   - 표준편차: {overall_std:.3f}")
    except Exception as e:
        print(f"   - 표준편차 계산 실패: {e}")
        overall_std = 0.0
    
    # NaN, inf 검사 (배치 단위로)
    nan_count = 0
    inf_count = 0
    batch_size = 100000
    
    for i in range(0, len(combined_features), batch_size):
        batch = combined_features[i:i+batch_size]
        nan_count += np.isnan(batch).sum()
        inf_count += np.isinf(batch).sum()
    
    print(f"   - NaN 값: {nan_count}")
    print(f"   - 무한값: {inf_count}")
    
    # 최종 데이터 저장
    print(f"\n💾 데이터 저장 중...")
    final_data = np.column_stack([combined_features, combined_labels])
    
    # 출력 디렉토리 생성
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    
    # numpy 파일로 저장
    np.save(OUTPUT_FILE, final_data)
    
    file_size = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)
    print(f"✅ 데이터 저장 완료: {OUTPUT_FILE}")
    print(f"   - 파일 크기: {file_size:.1f} MB")
    print(f"   - 형태: {final_data.shape}")
    
    # 메타데이터 저장
    metadata = {
        'creation_date': datetime.now().isoformat(),
        'source_directory': SOURCE_DIR,
        'total_files_processed': processed_files,
        'total_files_skipped': skipped_files,
        'total_samples': int(total_samples),
        'feature_dimensions': int(combined_features.shape[1]),
        'gesture_labels': GESTURE_LABELS,
        'gesture_distribution': dict(gesture_stats),
        'data_statistics': {
            'min': float(combined_features.min()),
            'max': float(combined_features.max()),
            'mean': float(combined_features.mean()),
            'std': float(overall_std),
            'nan_count': int(nan_count),
            'inf_count': int(inf_count)
        },
        'file_details': file_stats
    }
    
    with open(METADATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    print(f"✅ 메타데이터 저장: {METADATA_FILE}")
    
    return True

def analyze_merged_data():
    """병합된 데이터 분석"""
    if not os.path.exists(OUTPUT_FILE):
        print(f"❌ 병합된 데이터가 없습니다: {OUTPUT_FILE}")
        return
    
    print(f"\n🔍 병합된 데이터 분석:")
    print("-" * 40)
    
    # 데이터 로딩
    data = np.load(OUTPUT_FILE)
    features = data[:, :-1]
    labels = data[:, -1].astype(int)
    
    print(f"📊 기본 정보:")
    print(f"   - 데이터 형태: {data.shape}")
    print(f"   - 총 샘플: {len(data):,}")
    print(f"   - 특징 차원: {features.shape[1]}")
    print(f"   - 클래스 수: {len(np.unique(labels))}")
    
    # 클래스별 분포
    print(f"\n📈 클래스별 분포:")
    unique_labels, counts = np.unique(labels, return_counts=True)
    for label, count in zip(unique_labels, counts):
        gesture_name = LABEL_TO_NAME.get(label, f'unknown_{label}')
        percentage = count / len(labels) * 100
        print(f"   {label:2d} ({gesture_name:12s}): {count:6,} ({percentage:5.1f}%)")
    
    # 불균형 분석
    min_count = counts.min()
    max_count = counts.max()
    imbalance_ratio = max_count / min_count if min_count > 0 else float('inf')
    
    print(f"\n⚖️ 클래스 균형:")
    print(f"   - 최소 샘플: {min_count:,}")
    print(f"   - 최대 샘플: {max_count:,}")
    print(f"   - 불균형 비율: {imbalance_ratio:.1f}:1")
    
    if imbalance_ratio > 5:
        print(f"   ⚠️ 심한 불균형 감지! 데이터 증강 권장")
    elif imbalance_ratio > 2:
        print(f"   ⚠️ 약간의 불균형 존재")
    else:
        print(f"   ✅ 균형잡힌 분포")

# =============================================================================
# 메인 실행
# =============================================================================

def main():
    """메인 실행 함수"""
    print("🔄 기존 수집 데이터 → MLP 학습용 변환")
    print("data_collect_improved.py로 수집된 데이터 활용")
    print("=" * 60)
    
    # 병합 실행
    success = merge_existing_data()
    
    if success:
        # 분석 실행
        analyze_merged_data()
        
        print(f"\n🎉 데이터 병합 완료!")
        print(f"💡 다음 단계:")
        print(f"   1. python train_existing_mlp.py로 모델 학습")
        print(f"   2. 학습된 모델로 실시간 테스트")
        print(f"   3. 필요시 부족한 제스처 추가 수집")
    else:
        print(f"\n❌ 데이터 병합 실패!")

if __name__ == "__main__":

    main()
