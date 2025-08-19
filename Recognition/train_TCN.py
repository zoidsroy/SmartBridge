"""
TCN을 사용한 시퀀스 제스처 인식 모델 학습

"""

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, random_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import matplotlib.pyplot as plt
import seaborn as sns
import json
import os
import time
import pickle
from datetime import datetime
from collections import Counter
import glob


# 제스처 라벨 매핑 
SEQUENCE_GESTURES = {
    'clockwise': 0,          # 시계방향 원형
    'counter_clockwise': 1,  # 반시계방향 원형
    'star': 2,              # 별 모양
    'triangle': 3,          # 삼각형
    'square': 4,            # 사각형
    'heart': 5,             # 하트 모양
    'spiral': 6,            # 나선형
    'zigzag': 7,            # 지그재그
    'wave': 8,              # 물결
    'infinity': 9           # 무한대 기호
}

GESTURE_NAMES = list(SEQUENCE_GESTURES.keys())
LABEL_TO_NAME = {v: k for k, v in SEQUENCE_GESTURES.items()}

# 학습 설정
TRAINING_CONFIG = {
    'data_dir': './TCN_data',
    'sequence_length': 60,          # 시퀀스 길이
    'input_features': 99,           # 입력 특징 차원
    'num_classes': 10,  # 기본값, 데이터 로딩 후 업데이트됨
    
    # TCN 아키텍처
    'tcn_channels': [32, 64, 128, 64, 32],  # TCN 채널 크기
    'kernel_size': 3,               # 컨볼루션 커널 크기
    'dropout_rate': 0.3,            # 드롭아웃 비율
    'use_skip_connections': True,   # 스킵 연결 사용
    'use_batch_norm': True,         # 배치 정규화 사용
    
    # 학습 설정
    'batch_size': 32,               # 배치 크기
    'epochs': 150,                  # 에포크 수
    'learning_rate': 0.001,         # 학습률
    'weight_decay': 1e-4,           # 가중치 감쇠
    'train_ratio': 0.7,             # 학습 데이터 비율
    'val_ratio': 0.15,              # 검증 데이터 비율
    'test_ratio': 0.15,             # 테스트 데이터 비율
    
    # 최적화 설정
    'early_stopping_patience': 20,  # 조기 종료 patience
    'lr_scheduler_patience': 10,     # 학습률 감소 patience
    'lr_scheduler_factor': 0.5,      # 학습률 감소 비율
    'gradient_clip_value': 1.0,      # 그라디언트 클리핑
    'class_balancing': True,         # 클래스 균형 맞추기
}


class Chomp1d(nn.Module):
    def __init__(self, chomp_size):
        super(Chomp1d, self).__init__()
        self.chomp_size = chomp_size

    def forward(self, x):
        return x[:, :, :-self.chomp_size].contiguous()

class TemporalBlock(nn.Module):
    """TCN의 기본 블록"""
    def __init__(self, n_inputs, n_outputs, kernel_size, stride, dilation, padding, dropout=0.2, use_batch_norm=True):
        super(TemporalBlock, self).__init__()
        
        # 첫 번째 컨볼루션
        self.conv1 = nn.Conv1d(n_inputs, n_outputs, kernel_size,
                               stride=stride, padding=padding, dilation=dilation)
        self.chomp1 = Chomp1d(padding)
        self.bn1 = nn.BatchNorm1d(n_outputs) if use_batch_norm else nn.Identity()
        self.relu1 = nn.ReLU()
        self.dropout1 = nn.Dropout(dropout)

        # 두 번째 컨볼루션
        self.conv2 = nn.Conv1d(n_outputs, n_outputs, kernel_size,
                               stride=stride, padding=padding, dilation=dilation)
        self.chomp2 = Chomp1d(padding)
        self.bn2 = nn.BatchNorm1d(n_outputs) if use_batch_norm else nn.Identity()
        self.relu2 = nn.ReLU()
        self.dropout2 = nn.Dropout(dropout)

        # 스킵 연결을 위한 1x1 컨볼루션
        self.downsample = nn.Conv1d(n_inputs, n_outputs, 1) if n_inputs != n_outputs else None
        self.relu = nn.ReLU()
        
        # 가중치 초기화
        self.init_weights()

    def init_weights(self):
        """가중치 초기화"""
        self.conv1.weight.data.normal_(0, 0.01)
        self.conv2.weight.data.normal_(0, 0.01)
        if self.downsample is not None:
            self.downsample.weight.data.normal_(0, 0.01)

    def forward(self, x):
        # 첫 번째 컨볼루션 블록
        out = self.conv1(x)
        out = self.chomp1(out)
        out = self.bn1(out)
        out = self.relu1(out)
        out = self.dropout1(out)

        # 두 번째 컨볼루션 블록
        out = self.conv2(out)
        out = self.chomp2(out)
        out = self.bn2(out)
        out = self.relu2(out)
        out = self.dropout2(out)

        # 스킵 연결
        res = x if self.downsample is None else self.downsample(x)
        return self.relu(out + res)

class TemporalConvNet(nn.Module):
    """TCN 네트워크"""
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
    """시퀀스 제스처 인식용 TCN 모델"""
    def __init__(self, input_features, num_classes, tcn_channels, kernel_size=3, 
                 dropout_rate=0.3, use_skip_connections=True, use_batch_norm=True):
        super(SequenceTCN, self).__init__()
        
        self.input_features = input_features
        self.num_classes = num_classes
        self.use_skip_connections = use_skip_connections
        
        # 입력 정규화
        if use_batch_norm:
            self.input_norm = nn.BatchNorm1d(input_features)
        
        # TCN 백본
        self.tcn = TemporalConvNet(input_features, tcn_channels, kernel_size, dropout_rate, use_batch_norm)
        
        # Global pooling
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        
        # 분류기
        self.classifier = nn.Sequential(
            nn.Linear(tcn_channels[-1], tcn_channels[-1] // 2),
            nn.BatchNorm1d(tcn_channels[-1] // 2) if use_batch_norm else nn.Identity(),
            nn.ReLU(),
            nn.Dropout(dropout_rate),
            nn.Linear(tcn_channels[-1] // 2, num_classes)
        )
        
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
        # x shape: (batch, sequence_length, features)
        # TCN expects: (batch, features, sequence_length)
        x = x.transpose(1, 2)  # (batch, features, sequence_length)
        
        # 입력 정규화
        if hasattr(self, 'input_norm'):
            x = self.input_norm(x)
        
        # TCN 포워드
        tcn_out = self.tcn(x)  # (batch, channels, sequence_length)
        
        # Global pooling
        pooled = self.global_pool(tcn_out)  # (batch, channels, 1)
        pooled = pooled.squeeze(-1)  # (batch, channels)
        
        # 분류
        output = self.classifier(pooled)
        
        return output


class SequenceGestureDataset(Dataset):
    """시퀀스 제스처 데이터셋"""
    
    def __init__(self, sequences, labels):
        self.sequences = torch.FloatTensor(sequences)
        self.labels = torch.LongTensor(labels)
    
    def __len__(self):
        return len(self.sequences)
    
    def __getitem__(self, idx):
        return self.sequences[idx], self.labels[idx]


def load_sequence_data(config):
    """시퀀스 데이터 로딩"""
    print("  시퀀스 데이터 로딩 중...")
    
    data_dir = config['data_dir']
    
    # .npz 파일들 찾기
    npz_files = glob.glob(os.path.join(data_dir, "sequence_gestures_*.npz"))
    
    if not npz_files:
        print(f"  데이터 파일을 찾을 수 없습니다: {data_dir}")
        return None, None, None, None
    
    # 가장 최신 파일 사용
    latest_file = max(npz_files, key=os.path.getctime)
    print(f"     데이터 파일: {os.path.basename(latest_file)}")
    
    try:
        # 데이터 로딩
        data = np.load(latest_file, allow_pickle=True)
        sequences = data['sequences']           # (N, seq_len, features)
        gesture_names = data['gesture_names']   # (N,) - 각 샘플의 제스처 이름
        unique_gestures = data['unique_gestures'].tolist()  # 유니크한 제스처 목록
        gesture_to_label = data['gesture_to_label'].item()  # 제스처 -> 라벨 매핑
        
        # 제스처 이름을 라벨로 변환
        labels = np.array([gesture_to_label[name] for name in gesture_names])
        
        # 글로벌 변수 업데이트
        global SEQUENCE_GESTURES, LABEL_TO_NAME
        SEQUENCE_GESTURES = gesture_to_label
        LABEL_TO_NAME = {v: k for k, v in gesture_to_label.items()}
        
        print(f"  데이터 로딩 완료")
        print(f"   - 총 샘플: {len(sequences):,}")
        print(f"   - 시퀀스 길이: {sequences.shape[1]}")
        print(f"   - 특징 차원: {sequences.shape[2]}")
        print(f"   - 클래스 수: {len(unique_gestures)}")
        print(f"   - 수집된 제스처: {unique_gestures}")
        
        # 클래스별 분포
        label_counts = Counter(labels)
        print(f"   - 클래스별 분포:")
        for label in sorted(label_counts.keys()):
            count = label_counts[label]
            gesture_name = LABEL_TO_NAME.get(label, f'unknown_{label}')
            percentage = count / len(labels) * 100
            print(f"     {label:2d} ({gesture_name:15s}): {count:4,} ({percentage:5.1f}%)")
        
        return sequences, labels, unique_gestures, gesture_to_label
        
    except Exception as e:
        print(f"  데이터 로딩 실패: {e}")
        return None, None, None, None

def preprocess_sequences(sequences, labels, config):
    """시퀀스 데이터 전처리"""
    print("\n  시퀀스 데이터 전처리 중...")
    
    # 데이터 유효성 검사
    valid_mask = []
    for i, seq in enumerate(sequences):
        # NaN, inf 검사
        if np.isnan(seq).any() or np.isinf(seq).any():
            valid_mask.append(False)
            continue
        
        # 시퀀스 길이 검사
        if len(seq) != config['sequence_length']:
            valid_mask.append(False)
            continue
        
        valid_mask.append(True)
    
    valid_mask = np.array(valid_mask)
    valid_sequences = sequences[valid_mask]
    valid_labels = labels[valid_mask]
    
    if valid_mask.sum() < len(sequences):
        print(f"   - 제거된 무효 샘플: {(~valid_mask).sum():,}")
    
    print(f"   - 유효한 샘플: {len(valid_sequences):,}")
    

    # 모든 시퀀스를 하나로 합쳐서 통계 계산
    all_features = valid_sequences.reshape(-1, valid_sequences.shape[-1])
    scaler = StandardScaler()
    scaler.fit(all_features)
    
    # 각 시퀀스 정규화
    normalized_sequences = np.zeros_like(valid_sequences)
    for i, seq in enumerate(valid_sequences):
        normalized_sequences[i] = scaler.transform(seq)
    
    print(f"   - 정규화 완료")
    print(f"     원본 범위: [{valid_sequences.min():.3f}, {valid_sequences.max():.3f}]")
    print(f"     정규화 후: [{normalized_sequences.min():.3f}, {normalized_sequences.max():.3f}]")
    
    # 클래스 가중치 계산
    class_weights = None
    if config['class_balancing']:
        label_counts = Counter(valid_labels)
        total_samples = len(valid_labels)
        n_classes = len(label_counts)
        
        weights = {}
        for label in range(config['num_classes']):
            count = label_counts.get(label, 1)
            weights[label] = total_samples / (n_classes * count)
        
        class_weights = torch.FloatTensor([weights[i] for i in range(config['num_classes'])])
        print(f"   - 클래스 가중치 계산 완료")
    
    return normalized_sequences, valid_labels, scaler, class_weights

def create_data_loaders(sequences, labels, config):
    """데이터로더 생성"""
    print("\n  데이터로더 생성 중...")
    
    # 데이터셋 생성
    dataset = SequenceGestureDataset(sequences, labels)
    
    # 데이터 분할
    total_size = len(dataset)
    train_size = int(total_size * config['train_ratio'])
    val_size = int(total_size * config['val_ratio'])
    test_size = total_size - train_size - val_size
    
    train_dataset, val_dataset, test_dataset = random_split(
        dataset, [train_size, val_size, test_size],
        generator=torch.Generator().manual_seed(42)
    )
    
    # 데이터로더 생성 (Windows 호환성)
    train_loader = DataLoader(
        train_dataset, 
        batch_size=config['batch_size'], 
        shuffle=True, 
        num_workers=0,  # Windows 호환성
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
    
    return train_loader, val_loader, test_loader


def train_epoch(model, train_loader, criterion, optimizer, device, config):
    """한 에포크 학습"""
    model.train()
    total_loss = 0
    correct = 0
    total = 0
    
    for batch_idx, (data, targets) in enumerate(train_loader):
        data, targets = data.to(device), targets.to(device)
        
        optimizer.zero_grad()
        outputs = model(data)
        loss = criterion(outputs, targets)
        
        loss.backward()
        
        # 그라디언트 클리핑
        torch.nn.utils.clip_grad_norm_(model.parameters(), config['gradient_clip_value'])
        
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
    print("\n  TCN 시퀀스 제스처 모델 학습 시작!")
    print("=" * 60)
    
    # 손실 함수와 옵티마이저
    if class_weights is not None:
        criterion = nn.CrossEntropyLoss(weight=class_weights.to(device))
        print("  클래스 가중치 적용됨")
    else:
        criterion = nn.CrossEntropyLoss()
    
    optimizer = optim.AdamW(
        model.parameters(), 
        lr=config['learning_rate'],
        weight_decay=config['weight_decay']
    )
    
    # 학습률 스케줄러
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, 
        mode='max', 
        factor=config['lr_scheduler_factor'], 
        patience=config['lr_scheduler_patience'], 
        verbose=True
    )
    
    # 학습 기록
    history = {
        'train_loss': [], 'train_acc': [],
        'val_loss': [], 'val_acc': []
    }
    best_val_acc = 0
    best_model_state = None
    patience_counter = 0
    
    print(f"  모델 정보:")
    print(f"   - 파라미터 수: {sum(p.numel() for p in model.parameters()):,}")
    print(f"   - 학습 샘플: {len(train_loader.dataset):,}")
    print(f"   - 검증 샘플: {len(val_loader.dataset):,}")
    print(f"   - 배치 크기: {config['batch_size']}")
    print(f"   - 시퀀스 길이: {config['sequence_length']}")
    
    training_start_time = time.time()
    
    for epoch in range(config['epochs']):
        epoch_start = time.time()
        
        # 학습
        train_loss, train_acc = train_epoch(
            model, train_loader, criterion, optimizer, device, config
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
            status = "  NEW BEST!"
        else:
            patience_counter += 1
            status = f"({patience_counter}/{config['early_stopping_patience']})"
        
        # 진행 상황 출력
        if epoch % 5 == 0 or epoch == config['epochs'] - 1 or val_acc > best_val_acc:
            print(f"Epoch {epoch+1:3d}/{config['epochs']} | "
                  f"Train: {train_loss:.4f}/{train_acc:.2f}% | "
                  f"Val: {val_loss:.4f}/{val_acc:.2f}% | "
                  f"Time: {epoch_time:.1f}s | "
                  f"LR: {optimizer.param_groups[0]['lr']:.6f} | "
                  f"{status}")
        
        # 조기 종료
        if patience_counter >= config['early_stopping_patience']:
            print(f"  조기 종료 (patience={config['early_stopping_patience']})")
            break
    
    # 최고 성능 모델 로드
    model.load_state_dict(best_model_state)
    
    total_training_time = time.time() - training_start_time
    
    print(f"\n  학습 완료!")
    print(f"   - 최고 검증 정확도: {best_val_acc:.2f}%")
    print(f"   - 총 학습 시간: {total_training_time/60:.1f}분")
    print(f"   - 에포크당 평균: {total_training_time/(epoch+1):.1f}초")
    
    return model, history

def evaluate_model(model, test_loader, device):
    """모델 평가"""
    print("\n  모델 평가 중...")
    
    criterion = nn.CrossEntropyLoss()
    test_loss, test_acc, predictions, targets = validate_epoch(
        model, test_loader, criterion, device
    )
    
    print(f"  테스트 결과:")
    print(f"   - 손실: {test_loss:.4f}")
    print(f"   - 정확도: {test_acc:.2f}%")
    
    # 상세 분류 보고서
    target_names = [LABEL_TO_NAME.get(i, f'class_{i}') for i in range(TRAINING_CONFIG['num_classes'])]
    print(f"\n  상세 분류 보고서:")
    print(classification_report(
        targets, predictions, 
        target_names=target_names,
        zero_division=0
    ))
    
    return test_acc, predictions, targets

def plot_results(history, predictions, targets, save_path='tcn_sequence_results.png'):
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
    
    # 실제 존재하는 클래스만 표시
    existing_classes = sorted(list(set(targets + predictions)))
    existing_names = [target_names[i] for i in existing_classes]
    cm_existing = cm[np.ix_(existing_classes, existing_classes)]
    
    sns.heatmap(
        cm_existing, annot=True, fmt='d', cmap='Blues',
        xticklabels=existing_names, yticklabels=existing_names,
        ax=axes[1,0]
    )
    axes[1,0].set_title('Confusion Matrix')
    axes[1,0].set_xlabel('Predicted')
    axes[1,0].set_ylabel('True')
    
    # 4. 클래스별 정확도
    class_accuracies = []
    class_labels = []
    for i in existing_classes:
        mask = np.array(targets) == i
        if mask.sum() > 0:
            acc = accuracy_score(np.array(targets)[mask], np.array(predictions)[mask])
            class_accuracies.append(acc * 100)
            class_labels.append(LABEL_TO_NAME.get(i, f'{i}'))
    
    bars = axes[1,1].bar(range(len(class_accuracies)), class_accuracies)
    axes[1,1].set_title('Class-wise Accuracy')
    axes[1,1].set_xlabel('Class')
    axes[1,1].set_ylabel('Accuracy (%)')
    axes[1,1].set_xticks(range(len(class_labels)))
    axes[1,1].set_xticklabels(class_labels, rotation=45, ha='right')
    
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
    print(f"  결과 그래프가 '{save_path}'에 저장되었습니다.")

def save_model(model, scaler, config, test_accuracy, gesture_info):
    """모델과 전처리기 저장"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # 모델 저장
    model_path = f'sequence_tcn_model_{test_accuracy:.1f}pct.pth'
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': config,
        'gesture_labels': SEQUENCE_GESTURES,
        'label_to_name': LABEL_TO_NAME,
        'unique_gestures': gesture_info['unique_gestures'],
        'gesture_to_label': gesture_info['gesture_to_label'],
        'model_class': 'SequenceTCN',
        'test_accuracy': test_accuracy,
        'timestamp': timestamp,
        'data_source': 'sequence_collected_data'
    }, model_path)
    
    # 스케일러 저장
    scaler_path = f'sequence_tcn_scaler.pkl'
    with open(scaler_path, 'wb') as f:
        pickle.dump(scaler, f)
    
    print(f"  모델 저장 완료:")
    print(f"   - 모델: {model_path}")
    print(f"   - 스케일러: {scaler_path}")
    print(f"   - 테스트 정확도: {test_accuracy:.2f}%")
    print(f"   - 학습된 제스처: {gesture_info['unique_gestures']}")


def main():
    """메인 실행 함수"""
    print("  TCN 시퀀스 제스처 인식 모델 학습")
    print("=" * 60)
    
    # 디바이스 설정
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"  사용 디바이스: {device}")
    
    # 데이터 로딩
    sequences, labels, unique_gestures, gesture_to_label = load_sequence_data(TRAINING_CONFIG)
    if sequences is None:
        return
    
    # 클래스 수 업데이트
    TRAINING_CONFIG['num_classes'] = len(unique_gestures)
    print(f"  클래스 수 업데이트: {TRAINING_CONFIG['num_classes']}")
    
    # 데이터 전처리
    sequences_scaled, labels, scaler, class_weights = preprocess_sequences(
        sequences, labels, TRAINING_CONFIG
    )
    
    # 데이터로더 생성
    train_loader, val_loader, test_loader = create_data_loaders(
        sequences_scaled, labels, TRAINING_CONFIG
    )
    
    # 모델 생성
    print(f"\n  TCN 모델 생성...")
    model = SequenceTCN(
        input_features=TRAINING_CONFIG['input_features'],
        num_classes=TRAINING_CONFIG['num_classes'],
        tcn_channels=TRAINING_CONFIG['tcn_channels'],
        kernel_size=TRAINING_CONFIG['kernel_size'],
        dropout_rate=TRAINING_CONFIG['dropout_rate'],
        use_skip_connections=TRAINING_CONFIG['use_skip_connections'],
        use_batch_norm=TRAINING_CONFIG['use_batch_norm']
    ).to(device)
    
    print(f"   - 입력 특징: {TRAINING_CONFIG['input_features']}")
    print(f"   - 시퀀스 길이: {TRAINING_CONFIG['sequence_length']}")
    print(f"   - TCN 채널: {TRAINING_CONFIG['tcn_channels']}")
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
    gesture_info = {
        'unique_gestures': unique_gestures,
        'gesture_to_label': gesture_to_label
    }
    save_model(trained_model, scaler, TRAINING_CONFIG, test_accuracy, gesture_info)
    
    print(f"\n 학습 완료!")
    print(f"   - 최종 테스트 정확도: {test_accuracy:.2f}%")
    print(f"   - 모델 파일: sequence_tcn_model_{test_accuracy:.1f}pct.pth")
    print(f"   - 다음 단계: 실시간 테스트용 코드 작성")

if __name__ == "__main__":

    main()


