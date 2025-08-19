import 'package:flutter/material.dart';
import '../header.dart';
import '../services/gesture_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModeGestureCustomizationScreen extends StatefulWidget {
  final String keyName;
  final String deviceName;

  const ModeGestureCustomizationScreen({
    super.key,
    required this.keyName,
    required this.deviceName,
  });

  @override
  State<ModeGestureCustomizationScreen> createState() =>
      _ModeGestureCustomizationScreenState();
}

class _ModeGestureCustomizationScreenState
    extends State<ModeGestureCustomizationScreen> {
  Map<String, Map<String, dynamic>> _availableGestures = {};
  String? _selectedGestureKey;
  String? _selectedGestureName;
  String? _selectedGestureIcon;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🚀 ModeGestureCustomizationScreen 초기화 시작');
    print('📱 전달받은 keyName: ${widget.keyName}');
    print('📱 전달받은 deviceName: ${widget.deviceName}');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 모드 제스처 커스터마이징 데이터 로딩 시작...');
      print('📱 기기 ID: ${widget.keyName}');
      print('📱 기기 이름: ${widget.deviceName}');

      // 사용 가능한 제스처 로드
      final availableGestures = GestureService.getAvailableGestures();
      print('🤚 사용 가능한 제스처 개수: ${availableGestures.length}');

      // 현재 설정된 모드 진입 제스처 로드
      final currentGesture =
          await GestureService.getModeEntryGesture(widget.keyName);
      print('🎯 현재 설정된 모드 진입 제스처: $currentGesture');

      setState(() {
        _availableGestures = availableGestures;
        _selectedGestureKey = currentGesture;
        _selectedGestureName = currentGesture != null
            ? GestureService.getGestureName(currentGesture)
            : null;
        _selectedGestureIcon = currentGesture != null
            ? GestureService.getGestureIcon(currentGesture)
            : null;
        _isLoading = false;
      });

      print('✅ 데이터 로딩 완료');
    } catch (e) {
      print('❌ 데이터 로딩 오류: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.deviceName} 모드 진입 제스처 설정',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '기기 모드에 진입할 제스처를 선택하세요',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 새로고침 버튼
                  IconButton(
                    onPressed: () {
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔄 데이터 새로고침 완료')),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: _buildCustomizationContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 현재 설정된 제스처 표시
        _buildCurrentGestureSection(),

        const SizedBox(height: 24),

        // 제스처 선택 섹션
        _buildGestureSelectionSection(),
      ],
    );
  }

  Widget _buildCurrentGestureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🎯 현재 설정된 모드 진입 제스처',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedGestureKey != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '설정됨',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedGestureKey == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.gesture, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '아직 설정된 제스처가 없습니다',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '아래에서 원하는 제스처를 선택해주세요',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedGestureIcon!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedGestureName!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.deviceName} 모드 진입',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteModeEntryGesture(),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: '제스처 삭제',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🤚 제스처 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_availableGestures.length}개 제스처',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.deviceName} 모드에 진입할 제스처를 선택하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showGestureSelectionDialog,
              icon: const Icon(Icons.gesture),
              label:
                  Text(_selectedGestureKey == null ? '제스처 선택하기' : '제스처 변경하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGestureSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모드 진입 제스처 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.0,
            ),
            itemCount: _availableGestures.length,
            itemBuilder: (context, index) {
              final entry = _availableGestures.entries.elementAt(index);
              final gestureKey = entry.key;
              final gestureName = GestureService.getGestureName(gestureKey);
              final isSelected = gestureKey == _selectedGestureKey;

              return GestureDetector(
                onTap: () => _selectGesture(gestureKey, gestureName),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[100] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        GestureService.getGestureIcon(gestureKey),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        GestureService.getGestureName(gestureKey),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue[700] : Colors.black,
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectGesture(String gestureKey, String gestureName) async {
    try {
      print(
          '💾 모드 진입 제스처 저장: ${widget.keyName} (사용자: ${AuthService().currentUser?.uid})');
      print('📝 저장할 제스처: $gestureKey');

      // 기존 제스처가 있으면 먼저 삭제
      if (_selectedGestureKey != null) {
        print('🔄 기존 제스처 삭제 중: $_selectedGestureKey');
        await GestureService.deleteModeEntryGesture(widget.keyName);
      }

      // 새로운 제스처 저장
      final success = await GestureService.saveModeEntryGesture(
        widget.keyName,
        gestureKey,
      );

      if (success) {
        print('✅ 모드 진입 제스처 저장 완료');

        setState(() {
          _selectedGestureKey = gestureKey;
          _selectedGestureName = GestureService.getGestureName(gestureKey);
          _selectedGestureIcon = GestureService.getGestureIcon(gestureKey);
        });

        if (mounted) {
          Navigator.pop(context); // 다이얼로그 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ ${widget.deviceName} 모드 진입 제스처가 $gestureName으로 설정되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('저장 실패');
      }
    } catch (e) {
      print('❌ 모드 진입 제스처 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 제스처 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteModeEntryGesture() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제스처 삭제'),
        content: Text('${widget.deviceName} 모드 진입 제스처를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await GestureService.deleteModeEntryGesture(widget.keyName);

        if (success) {
          setState(() {
            _selectedGestureKey = null;
            _selectedGestureName = null;
            _selectedGestureIcon = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${widget.deviceName} 모드 진입 제스처 삭제 완료'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('삭제 실패');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 제스처 삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
