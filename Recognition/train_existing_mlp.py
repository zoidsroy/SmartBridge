# train_existing_mlp.py
"""
기존 수집된 데이터로 MLP 모델 학습
merge_existing_data.py로 병합된 데이터 사용

Author: AIoT Project Team
Date: 2024
"""

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split, StratifiedShuffleSplit
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import matplotlib.pyplot as plt
import seaborn as sns
import pickle
import os
import time
import json
from collections import Counter
from datetime import datetime

# =============================================================================
# 설정 및 상수
# =============================================================================

# 제스처 라벨 매핑 (기존 데이터와 동일)
GESTURE_LABELS = {
    'four': 0, 'horizontal_V': 1, 'ok': 2, 'one': 3, 'promise': 4,
    'small_heart': 5, 'spider_man': 6, 'three': 7, 'three2': 8, 
    'thumbs_down': 9, 'thumbs_left': 10, 'thumbs_right': 11, 
    'thumbs_up': 12, 'two': 13, 'vertical_V': 14, 'nothing': 15
}

LABEL_TO_NAME = {v: k for k, v in GESTURE_LABELS.items()}

# 학습 설정 (기존 데이터에 최적화)
TRAINING_CONFIG = {
    'data_file': './gesture_data/merged_existing_data_16.npy',
    'metadata_file': './gesture_data/merged_data_metadata_16.json',
    'input_dim': 99,           # 특징 차원 (84 + 15)
    'num_classes': 16,         # 제스처 클래스 수
    'hidden_sizes': [512, 256, 128, 64],  # 대량 데이터에 적합한 구조
    'dropout_rate': 0.4,       # 과적합 방지
    'use_batch_norm': True,    # 배치 정규화 사용
    'batch_size': 128,         # 대량 데이터용 배치 크기
    'epochs': 100,             # 충분한 학습
    'learning_rate': 0.001,    # 학습률
    'weight_decay': 1e-4,      # 가중치 감쇠
    'train_ratio': 0.7,        # 학습 데이터 비율
    'val_ratio': 0.15,         # 검증 데이터 비율
    'test_ratio': 0.15,        # 테스트 데이터 비율
    'early_stopping_patience': 15,  # 조기 종료
    'save_best_only': True,    # 최고 성능만 저장
    'class_balancing': True,   # 클래스 가중치 적용
}

# =============================================================================
# 데이터셋 클래스
# =============================================================================

class ExistingGestureDataset(Dataset):
    """기존 수집 데이터용 데이터셋"""
    
    def __init__(self, features, labels):
        self.features = torch.FloatTensor(features)
        self.labels = torch.LongTensor(labels)
    
    def __len__(self):
        return len(self.features)
    
    def __getitem__(self, idx):
        return self.features[idx], self.labels[idx]

# =============================================================================
# MLP 모델 (기존 데이터용 최적화)
# =============================================================================

class ExistingDataMLP(nn.Module):
    """기존 데이터용 MLP 모델"""
    
    def __init__(self, input_dim=99, num_classes=16, hidden_sizes=[512, 256, 128, 64], 
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
            # Linear layer
            layers.append(nn.Linear(prev_size, hidden_size))
            
            # Batch Normalization
            if use_batch_norm:
                layers.append(nn.BatchNorm1d(hidden_size))
            
            # Activation
            layers.append(nn.ReLU(inplace=True))
            
            # Dropout
            layers.append(nn.Dropout(dropout_rate))
            
            prev_size = hidden_size
        
        # 출력층
        layers.append(nn.Linear(prev_size, num_classes))
        
        self.network = nn.Sequential(*layers)
        
        # 가중치 초기화
        self._initialize_weights()
    
    def _initialize_weights(self):
        """가중치 초기화"""
        for m in self.modules():
            if isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
    
    def forward(self, x):
        # 입력 정규화
        if hasattr(self, 'input_norm'):
            x = self.input_norm(x)
        
        return self.network(x)

# =============================================================================
# 데이터 로딩 및 전처리
# =============================================================================

def load_existing_data(config):
    """기존 병합 데이터 로딩"""
    print("📁 기존 병합 데이터 로딩 중...")
    
    data_file = config['data_file']
    metadata_file = config['metadata_file']
    
    # 데이터 파일 확인
    if not os.path.exists(data_file):
        print(f"❌ 데이터 파일을 찾을 수 없습니다: {data_file}")
        print("먼저 merge_existing_data.py를 실행해주세요.")
        return None, None
    
    # 메타데이터 로딩
    if os.path.exists(metadata_file):
        with open(metadata_file, 'r', encoding='utf-8') as f:
            metadata = json.load(f)
        print(f"   📋 메타데이터 로딩 완료")
        print(f"   - 생성 날짜: {metadata.get('creation_date', 'Unknown')}")
        print(f"   - 처리된 파일: {metadata.get('total_files_processed', 0)}개")
    
    # 데이터 로딩
    try:
        data = np.load(data_file)
        features = data[:, :-1].astype(np.float32)
        labels = data[:, -1].astype(int)
        
        print(f"✅ 데이터 로딩 완료")
        print(f"   - 총 샘플: {len(features):,}")
        print(f"   - 특징 차원: {features.shape[1]}")
        print(f"   - 라벨 범위: {labels.min()} ~ {labels.max()}")
        print(f"   - 데이터 범위: [{features.min():.3f}, {features.max():.3f}]")
        
        # 제스처별 분포
        label_counts = Counter(labels)
        print(f"   - 제스처별 분포:")
        for label in sorted(label_counts.keys()):
            count = label_counts[label]
            gesture_name = LABEL_TO_NAME.get(label, f'unknown_{label}')
            percentage = count / len(labels) * 100
            print(f"     {label:2d} ({gesture_name:12s}): {count:6,} ({percentage:5.1f}%)")
        
        return features, labels
        
    except Exception as e:
        print(f"❌ 데이터 로딩 실패: {e}")
        return None, None

def preprocess_data(features, labels, config):
    """데이터 전처리"""
    print("\n🔄 데이터 전처리 중...")
    
    # 유효한 라벨만 필터링
    valid_mask = (labels >= 0) & (labels < config['num_classes'])
    features = features[valid_mask]
    labels = labels[valid_mask]
    
    print(f"   - 유효한 샘플: {len(features):,}")
    
    # 데이터 품질 검사
    nan_mask = np.isnan(features).any(axis=1)
    inf_mask = np.isinf(features).any(axis=1)
    invalid_mask = nan_mask | inf_mask
    
    if invalid_mask.any():
        print(f"   - 제거된 무효 샘플: {invalid_mask.sum():,}")
        features = features[~invalid_mask]
        labels = labels[~invalid_mask]
    
    # 특징 정규화
    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)
    
    print(f"   - 정규화 전 범위: [{features.min():.3f}, {features.max():.3f}]")
    print(f"   - 정규화 후 범위: [{features_scaled.min():.3f}, {features_scaled.max():.3f}]")
    print(f"   - 평균: {features_scaled.mean():.6f}, 표준편차: {features_scaled.std():.6f}")
    
    # 클래스 가중치 계산 (불균형 데이터 대응)
    class_weights = None
    if config['class_balancing']:
        label_counts = Counter(labels)
        total_samples = len(labels)
        n_classes = len(label_counts)
        
        # 균형 가중치 계산
        weights = {}
        for label in range(config['num_classes']):
            count = label_counts.get(label, 1)  # 0개인 경우 1로 설정
            weights[label] = total_samples / (n_classes * count)
        
        class_weights = torch.FloatTensor([weights[i] for i in range(config['num_classes'])])
        print(f"   - 클래스 가중치 적용됨")
    
    return features_scaled, labels, scaler, class_weights

def create_data_loaders(features, labels, config):
    """데이터로더 생성 (계층화 분할)"""
    print("\n📦 데이터로더 생성 중...")
    
    # 계층화 분할 (클래스 비율 유지)
    sss_test = StratifiedShuffleSplit(n_splits=1, test_size=config['test_ratio'], random_state=42)
    train_val_idx, test_idx = next(sss_test.split(features, labels))
    
    X_train_val, X_test = features[train_val_idx], features[test_idx]
    y_train_val, y_test = labels[train_val_idx], labels[test_idx]
    
    # 검증 데이터 분할
    val_size_adjusted = config['val_ratio'] / (config['train_ratio'] + config['val_ratio'])
    sss_val = StratifiedShuffleSplit(n_splits=1, test_size=val_size_adjusted, random_state=42)
    train_idx, val_idx = next(sss_val.split(X_train_val, y_train_val))
    
    X_train, X_val = X_train_val[train_idx], X_train_val[val_idx]
    y_train, y_val = y_train_val[train_idx], y_train_val[val_idx]
    
    # 데이터셋 생성
    train_dataset = ExistingGestureDataset(X_train, y_train)
    val_dataset = ExistingGestureDataset(X_val, y_val)
    test_dataset = ExistingGestureDataset(X_test, y_test)
    
    # 데이터로더 생성 (Windows 호환성)
    train_loader = DataLoader(
        train_dataset, 
        batch_size=config['batch_size'], 
        shuffle=True, 
        num_workers=0,
        pin_memory=False
    )
    val_loader = DataLoader(
        val_dataset, 
        batch_size=config['batch_size'], 
        shuffle=False, 
        num_workers=0,
        pin_memory=False
    )
    test_loader = DataLoader(
        test_dataset, 
        batch_size=config['batch_size'], 
        shuffle=False, 
        num_workers=0,
        pin_memory=False
    )
    
    print(f"   - 학습: {len(train_dataset):,} 샘플")
    print(f"   - 검증: {len(val_dataset):,} 샘플") 
    print(f"   - 테스트: {len(test_dataset):,} 샘플")
    
    # 분할 후 클래스 분포 확인
    train_label_counts = Counter(y_train)
    val_label_counts = Counter(y_val)
    test_label_counts = Counter(y_test)
    
    print(f"   - 클래스 분포 (학습/검증/테스트):")
    for label in sorted(set(labels)):
        gesture_name = LABEL_TO_NAME.get(label, f'unknown_{label}')
        train_count = train_label_counts.get(label, 0)
        val_count = val_label_counts.get(label, 0)
        test_count = test_label_counts.get(label, 0)
        print(f"     {label:2d} ({gesture_name:10s}): {train_count:4,}/{val_count:3,}/{test_count:3,}")
    
    return train_loader, val_loader, test_loader

# =============================================================================
# 학습 함수들
# =============================================================================

def train_epoch(model, train_loader, criterion, optimizer, device):
    """한 에포크 학습"""
    model.train()
    total_loss = 0
    correct = 0
    total = 0
    
    for data, targets in train_loader:
        data, targets = data.to(device), targets.to(device)
        
        optimizer.zero_grad()
        outputs = model(data)
        loss = criterion(outputs, targets)
        
        loss.backward()
        # 그라디언트 클리핑 (안정성 향상)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()
        
        total_loss += loss.item()
        _, predicted = outputs.max(1)
        total += targets.size(0)
        correct += predicted.eq(targets).sum().item()
    
    avg_loss = total_loss / len(train_loader)
    accuracy = 100. * correct / total
    
    return avg_loss, accuracy

def validate_epoch(model, val_loader, criterion, device):
    """검증 에포크"""
    model.eval()
    total_loss = 0
    correct = 0
    total = 0
    all_predictions = []
    all_targets = []
    
    with torch.no_grad():
        for data, targets in val_loader:
            data, targets = data.to(device), targets.to(device)
            outputs = model(data)
            loss = criterion(outputs, targets)
            
            total_loss += loss.item()
            _, predicted = outputs.max(1)
            total += targets.size(0)
            correct += predicted.eq(targets).sum().item()
            
            all_predictions.extend(predicted.cpu().numpy())
            all_targets.extend(targets.cpu().numpy())
    
    avg_loss = total_loss / len(val_loader)
    accuracy = 100. * correct / total
    
    return avg_loss, accuracy, all_predictions, all_targets

def train_model(model, train_loader, val_loader, config, device, class_weights=None):
    """모델 학습 메인 함수"""
    print("\n🚀 기존 데이터 MLP 모델 학습 시작!")
    print("=" * 60)
    
    # 손실 함수와 옵티마이저
    if class_weights is not None:
        criterion = nn.CrossEntropyLoss(weight=class_weights.to(device))
        print("⚖️ 클래스 가중치 적용됨")
    else:
        criterion = nn.CrossEntropyLoss()
    
    optimizer = optim.AdamW(
        model.parameters(), 
        lr=config['learning_rate'],
        weight_decay=config['weight_decay']
    )
    
    # 학습률 스케줄러
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='max', factor=0.5, patience=5, verbose=True
    )
    
    # 학습 기록
    history = {
        'train_loss': [], 'train_acc': [],
        'val_loss': [], 'val_acc': []
    }
    best_val_acc = 0
    best_model_state = None
    patience_counter = 0
    
    print(f"🔧 모델 정보:")
    print(f"   - 파라미터 수: {sum(p.numel() for p in model.parameters()):,}")
    print(f"   - 학습 샘플: {len(train_loader.dataset):,}")
    print(f"   - 검증 샘플: {len(val_loader.dataset):,}")
    print(f"   - 배치 크기: {config['batch_size']}")
    print(f"   - 학습률: {config['learning_rate']}")
    
    training_start_time = time.time()
    
    for epoch in range(config['epochs']):
        epoch_start = time.time()
        
        # 학습
        train_loss, train_acc = train_epoch(
            model, train_loader, criterion, optimizer, device
        )
        
        # 검증
        val_loss, val_acc, _, _ = validate_epoch(
            model, val_loader, criterion, device
        )
        
        # 스케줄러 업데이트
        scheduler.step(val_acc)
        
        epoch_time = time.time() - epoch_start
        
        # 기록 저장
        history['train_loss'].append(train_loss)
        history['train_acc'].append(train_acc)
        history['val_loss'].append(val_loss)
        history['val_acc'].append(val_acc)
        
        # 최고 성능 모델 저장
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_model_state = model.state_dict().copy()
            patience_counter = 0
            status = "🎯 NEW BEST!"
        else:
            patience_counter += 1
            status = f"({patience_counter}/{config['early_stopping_patience']})"
        
        # 진행 상황 출력 (매 5 에포크마다)
        if epoch % 5 == 0 or epoch == config['epochs'] - 1 or val_acc > best_val_acc:
            print(f"Epoch {epoch+1:3d}/{config['epochs']} | "
                  f"Train: {train_loss:.4f}/{train_acc:.2f}% | "
                  f"Val: {val_loss:.4f}/{val_acc:.2f}% | "
                  f"Time: {epoch_time:.1f}s | "
                  f"LR: {optimizer.param_groups[0]['lr']:.6f} | "
                  f"{status}")
        
        # 조기 종료
        if patience_counter >= config['early_stopping_patience']:
            print(f"⏹️ 조기 종료 (patience={config['early_stopping_patience']})")
            break
    
    # 최고 성능 모델 로드
    model.load_state_dict(best_model_state)
    
    total_training_time = time.time() - training_start_time
    
    print(f"\n✅ 학습 완료!")
    print(f"   - 최고 검증 정확도: {best_val_acc:.2f}%")
    print(f"   - 총 학습 시간: {total_training_time/60:.1f}분")
    print(f"   - 에포크당 평균: {total_training_time/(epoch+1):.1f}초")
    
    return model, history

def evaluate_model(model, test_loader, device):
    """모델 평가"""
    print("\n📊 모델 평가 중...")
    
    criterion = nn.CrossEntropyLoss()
    test_loss, test_acc, predictions, targets = validate_epoch(
        model, test_loader, criterion, device
    )
    
    print(f"🎯 테스트 결과:")
    print(f"   - 손실: {test_loss:.4f}")
    print(f"   - 정확도: {test_acc:.2f}%")
    
    # 상세 분류 보고서
    target_names = [LABEL_TO_NAME.get(i, f'class_{i}') for i in range(TRAINING_CONFIG['num_classes'])]
    print(f"\n📋 상세 분류 보고서:")
    print(classification_report(
        targets, predictions, 
        target_names=target_names,
        zero_division=0
    ))
    
    return test_acc, predictions, targets

def plot_results(history, predictions, targets, save_path='existing_mlp_results.png'):
    """결과 시각화"""
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    
    # 1. 학습 곡선 (손실)
    axes[0,0].plot(history['train_loss'], label='Train Loss', color='blue')
    axes[0,0].plot(history['val_loss'], label='Validation Loss', color='red')
    axes[0,0].set_title('Training and Validation Loss')
    axes[0,0].set_xlabel('Epoch')
    axes[0,0].set_ylabel('Loss')
    axes[0,0].legend()
    axes[0,0].grid(True)
    
    # 2. 학습 곡선 (정확도)
    axes[0,1].plot(history['train_acc'], label='Train Accuracy', color='blue')
    axes[0,1].plot(history['val_acc'], label='Validation Accuracy', color='red')
    axes[0,1].set_title('Training and Validation Accuracy')
    axes[0,1].set_xlabel('Epoch')
    axes[0,1].set_ylabel('Accuracy (%)')
    axes[0,1].legend()
    axes[0,1].grid(True)
    
    # 3. 혼동 행렬
    cm = confusion_matrix(targets, predictions)
    target_names = [LABEL_TO_NAME.get(i, f'class_{i}') for i in range(TRAINING_CONFIG['num_classes'])]
    
    sns.heatmap(
        cm, annot=True, fmt='d', cmap='Blues',
        xticklabels=target_names, yticklabels=target_names,
        ax=axes[1,0]
    )
    axes[1,0].set_title('Confusion Matrix')
    axes[1,0].set_xlabel('Predicted')
    axes[1,0].set_ylabel('True')
    
    # 4. 클래스별 정확도
    class_accuracies = []
    for i in range(TRAINING_CONFIG['num_classes']):
        mask = np.array(targets) == i
        if mask.sum() > 0:
            acc = accuracy_score(np.array(targets)[mask], np.array(predictions)[mask])
            class_accuracies.append(acc * 100)
        else:
            class_accuracies.append(0)
    
    bars = axes[1,1].bar(range(TRAINING_CONFIG['num_classes']), class_accuracies)
    axes[1,1].set_title('Class-wise Accuracy')
    axes[1,1].set_xlabel('Class')
    axes[1,1].set_ylabel('Accuracy (%)')
    axes[1,1].set_xticks(range(TRAINING_CONFIG['num_classes']))
    axes[1,1].set_xticklabels([LABEL_TO_NAME.get(i, f'{i}') for i in range(TRAINING_CONFIG['num_classes'])], 
                              rotation=45, ha='right')
    
    # 색상 코딩
    for bar, acc in zip(bars, class_accuracies):
        if acc >= 95:
            bar.set_color('darkgreen')
        elif acc >= 90:
            bar.set_color('green')
        elif acc >= 80:
            bar.set_color('orange')
        else:
            bar.set_color('red')
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    plt.show()
    print(f"📊 결과 그래프가 '{save_path}'에 저장되었습니다.")

def save_model(model, scaler, config, test_accuracy):
    """모델과 전처리기 저장"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # 모델 저장
    model_path = f'existing_mlp_model_{test_accuracy:.1f}pct.pth'
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': config,
        'gesture_labels': GESTURE_LABELS,
        'label_to_name': LABEL_TO_NAME,
        'model_class': 'ExistingDataMLP',
        'test_accuracy': test_accuracy,
        'timestamp': timestamp,
        'data_source': 'existing_collected_data'
    }, model_path)
    
    # 스케일러 저장
    scaler_path = f'existing_mlp_scaler.pkl'
    with open(scaler_path, 'wb') as f:
        pickle.dump(scaler, f)
    
    print(f"💾 모델 저장 완료:")
    print(f"   - 모델: {model_path}")
    print(f"   - 스케일러: {scaler_path}")
    print(f"   - 테스트 정확도: {test_accuracy:.2f}%")

# =============================================================================
# 메인 실행 함수
# =============================================================================

def main():
    """메인 실행 함수"""
    print("🤖 기존 수집 데이터 MLP 모델 학습")
    print("data_collect_improved.py로 수집된 데이터 활용")
    print("=" * 60)
    
    # 디바이스 설정
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"🔧 사용 디바이스: {device}")
    
    # 데이터 로딩
    features, labels = load_existing_data(TRAINING_CONFIG)
    if features is None:
        return
    
    # 데이터 전처리
    features_scaled, labels, scaler, class_weights = preprocess_data(
        features, labels, TRAINING_CONFIG
    )
    
    # 데이터로더 생성
    train_loader, val_loader, test_loader = create_data_loaders(
        features_scaled, labels, TRAINING_CONFIG
    )
    
    # 모델 생성
    print(f"\n🧠 기존 데이터 MLP 모델 생성...")
    model = ExistingDataMLP(
        input_dim=TRAINING_CONFIG['input_dim'],
        num_classes=TRAINING_CONFIG['num_classes'],
        hidden_sizes=TRAINING_CONFIG['hidden_sizes'],
        dropout_rate=TRAINING_CONFIG['dropout_rate'],
        use_batch_norm=TRAINING_CONFIG['use_batch_norm']
    ).to(device)
    
    print(f"   - 입력 차원: {TRAINING_CONFIG['input_dim']}")
    print(f"   - 숨은층: {TRAINING_CONFIG['hidden_sizes']}")
    print(f"   - 출력 클래스: {TRAINING_CONFIG['num_classes']}")
    print(f"   - 파라미터 수: {sum(p.numel() for p in model.parameters()):,}")
    
    # 모델 학습
    trained_model, history = train_model(
        model, train_loader, val_loader, TRAINING_CONFIG, device, class_weights
    )
    
    # 모델 평가
    test_accuracy, predictions, targets = evaluate_model(
        trained_model, test_loader, device
    )
    
    # 결과 시각화
    plot_results(history, predictions, targets)
    
    # 모델 저장
    save_model(trained_model, scaler, TRAINING_CONFIG, test_accuracy)
    
    print(f"\n🎉 학습 완료!")
    print(f"   - 최종 테스트 정확도: {test_accuracy:.2f}%")
    print(f"   - 모델 파일: existing_mlp_model_{test_accuracy:.1f}pct.pth")
    print(f"   - 다음 단계: 실시간 테스트용 코드 작성")

if __name__ == "__main__":
    main()