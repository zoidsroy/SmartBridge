import 'package:flutter/material.dart';
import '../header.dart';
import '../services/gesture_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GestureCustomizationScreen extends StatefulWidget {
  final String keyName;
  final String deviceName;

  const GestureCustomizationScreen({
    super.key,
    required this.keyName,
    required this.deviceName,
  });

  @override
  State<GestureCustomizationScreen> createState() =>
      _GestureCustomizationScreenState();
}

class _GestureCustomizationScreenState
    extends State<GestureCustomizationScreen> {
  Map<String, Map<String, dynamic>> _availableGestures = {};
  List<Map<String, String>> _deviceActions = [];
  Map<String, Map<String, String>> _gestureMappings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 제스처 커스터마이징 데이터 로딩 시작...');
      print('📱 기기 ID: ${widget.keyName}');
      print('📱 기기 이름: ${widget.deviceName}');

      // 사용 가능한 제스처 로드
      final availableGestures = GestureService.getAvailableGestures();
      print('🤚 사용 가능한 제스처 개수: ${availableGestures.length}');

      // 기기 동작 로드
      final allDeviceActions = GestureService.getDeviceActions();
      print('🏠 전체 기기 동작 데이터: ${allDeviceActions.keys}');

      final deviceActions = allDeviceActions[widget.keyName] ?? [];
      print('🎯 ${widget.keyName} 기기 동작 개수: ${deviceActions.length}');
      print('📝 ${widget.keyName} 기기 동작 목록: $deviceActions');

      // 현재 설정된 제스처 매핑 로드
      final gestureMappings =
          await GestureService.getDeviceGestureMapping(widget.keyName);
      print('🔗 현재 제스처 매핑: $gestureMappings');

      setState(() {
        _availableGestures = availableGestures;
        _deviceActions = deviceActions;
        _gestureMappings = gestureMappings;
        _isLoading = false;
      });

      print('✅ 데이터 로딩 완료');
      print('📊 최종 상태:');
      print('  - 사용 가능한 제스처: ${_availableGestures.length}개');
      print('  - 기기 동작: ${_deviceActions.length}개');
      print('  - 제스처 매핑: ${_gestureMappings.length}개');
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
                        '${widget.deviceName} 제스처 설정',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '원하는 동작에 제스처를 연결하세요',
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('제스처 데이터를 불러오는 중...'),
                        ],
                      ),
                    )
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
    // 기기 액션이 없는 경우 에러 처리
    if (_deviceActions.isEmpty) {
      return _buildNoActionsView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 기기 동작 기반 매핑 섹션 (주요 기능)
          _buildDeviceActionMappingSection(),
        ],
      ),
    );
  }

  Widget _buildNoActionsView() {
    // 디버그 정보 수집
    final allDeviceActions = GestureService.getDeviceActions();
    final availableKeys = allDeviceActions.keys.toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              '기기 동작을 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            // 디버그 정보 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔍 디버그 정보:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '전달받은 keyName: "${widget.keyName}"',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '전달받은 deviceName: "${widget.deviceName}"',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '사용 가능한 기기 키 목록:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600]),
                  ),
                  ...availableKeys.map((key) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '• "$key" → ${allDeviceActions[key]?.length ?? 0}개 동작',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      )),
                  const SizedBox(height: 8),
                  Text(
                    '현재 제스처 개수: ${_availableGestures.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '매핑 개수: ${_gestureMappings.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceActionMappingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '🎯 ${widget.deviceName} 동작별 제스처 설정',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_deviceActions.length}개 동작',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '각 동작에 원하는 제스처를 연결하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref(
                      'control_gesture/${FirebaseAuth.instance.currentUser?.uid}/${widget.keyName}')
                  .onValue,
              builder: (context, snapshot) {
                // StreamBuilder에서 직접 데이터 처리
                Map<String, String> actionToGesture = {};
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  for (final entry in data.entries) {
                    final gestureId = entry.key.toString();
                    final mapping = entry.value as Map<dynamic, dynamic>;
                    final control = mapping['control']?.toString();
                    if (control != null) {
                      actionToGesture[control] = gestureId;
                    }
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _deviceActions.map((action) {
                    final control = action['control']!;
                    final label = action['label']!;
                    final currentGesture = actionToGesture[control];
                    final hasGesture = currentGesture != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasGesture ? Colors.green[50] : Colors.grey[50],
                        border: Border.all(
                          color: hasGesture
                              ? Colors.green[200]!
                              : Colors.grey[200]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // 동작 정보
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  control,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),

                          // 현재 매핑된 제스처 또는 추가 버튼
                          Expanded(
                            flex: 2,
                            child: hasGesture
                                ? Row(
                                    children: [
                                      Text(
                                        GestureService.getGestureIcon(
                                            currentGesture),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          GestureService.getGestureName(
                                              currentGesture),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '제스처 없음',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),

                          // 액션 버튼들
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasGesture)
                                IconButton(
                                  onPressed: () => _showGestureChangeDialog(
                                      control, label, currentGesture),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 12),
                                  tooltip: '제스처 변경',
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  padding: const EdgeInsets.all(1),
                                ),
                              IconButton(
                                onPressed: hasGesture
                                    ? () => _deleteGestureMapping(
                                        currentGesture,
                                        GestureService.getGestureName(
                                            currentGesture))
                                    : () => _showGestureSelectionForAction(
                                        control, label),
                                icon: Icon(
                                  hasGesture
                                      ? Icons.delete_outline
                                      : Icons.add_circle_outline,
                                  size: 12,
                                  color: hasGesture ? Colors.red : Colors.blue,
                                ),
                                tooltip: hasGesture ? '제스처 삭제' : '제스처 추가',
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.all(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMappingsSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '📊 제스처 연결 현황',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Builder(
                  builder: (context) {
                    int mappedCount = _gestureMappings.length;
                    int totalActions = _deviceActions.length;
                    return Text(
                      '$mappedCount / $totalActions 연결됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref(
                      'control_gesture/${FirebaseAuth.instance.currentUser?.uid}/${widget.keyName}')
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '아직 연결된 제스처가 없습니다\n위의 동작 목록에서 제스처를 추가해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                final data =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                int totalActions = _deviceActions.length;
                int mappedCount = data.length;
                double percentage = mappedCount / totalActions;

                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 0.7
                            ? Colors.green
                            : percentage >= 0.4
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '연결률 ${(percentage * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${totalActions - mappedCount}개 동작 남음',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableGesturesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🤚 빠른 제스처 추가',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref(
                          'control_gesture/${FirebaseAuth.instance.currentUser?.uid}/${widget.keyName}')
                      .onValue,
                  builder: (context, snapshot) {
                    int totalGestures = _availableGestures.length;
                    int usedCount = 0;

                    if (snapshot.hasData &&
                        snapshot.data?.snapshot.value != null) {
                      final data = snapshot.data!.snapshot.value
                          as Map<dynamic, dynamic>;
                      usedCount = data.length;
                    }

                    int unusedCount = totalGestures - usedCount;

                    return Text(
                      '$unusedCount개 제스처 사용 가능',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '동작이 정해지지 않은 제스처를 먼저 선택하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref(
                      'control_gesture/${FirebaseAuth.instance.currentUser?.uid}/${widget.keyName}')
                  .onValue,
              builder: (context, snapshot) {
                // 현재 사용 중인 제스처 목록 파악
                Set<String> usedGestures = {};
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  usedGestures = data.keys.map((k) => k.toString()).toSet();
                }

                // 사용되지 않은 제스처만 필터링
                final unusedGestures =
                    Map<String, Map<String, dynamic>>.fromEntries(
                        _availableGestures.entries.where(
                            (entry) => !usedGestures.contains(entry.key)));

                if (unusedGestures.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle,
                            size: 48, color: Colors.green[400]),
                        const SizedBox(height: 8),
                        Text(
                          '모든 제스처가 연결되었습니다!',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '위의 동작 목록에서 기존 연결을 수정할 수 있어요',
                          style:
                              TextStyle(color: Colors.green[600], fontSize: 12),
                        ),
                      ],
                    ),
                  );
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: unusedGestures.length,
                    itemBuilder: (context, index) {
                      final entry = unusedGestures.entries.elementAt(index);
                      final gestureId = entry.key;

                      return GestureDetector(
                        onTap: () => _showActionSelectionDialog(gestureId,
                            GestureService.getGestureName(gestureId)),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                GestureService.getGestureIcon(gestureId),
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                GestureService.getGestureName(gestureId),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceActionsDebugView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 ${widget.deviceName} 사용 가능한 동작',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_deviceActions.isEmpty)
              const Text('사용 가능한 동작이 없습니다.')
            else
              ...(_deviceActions.map((action) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${action['label']} (${action['control']})'),
                      ],
                    ),
                  ))),
          ],
        ),
      ),
    );
  }

  void _showGestureSelectionForAction(String control, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label 동작에 연결할 제스처 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('control_gesture/${widget.keyName}')
                .onValue,
            builder: (context, snapshot) {
              // 현재 사용 중인 제스처 목록 파악
              Set<String> usedGestures = {};
              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                final data =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                usedGestures = data.keys.map((k) => k.toString()).toSet();
              }

              // 사용 가능한 제스처 목록
              final availableGestures = _availableGestures.entries
                  .where((entry) => !usedGestures.contains(entry.key))
                  .toList();

              if (availableGestures.isEmpty) {
                return const Text('사용 가능한 제스처가 없습니다.\n기존 제스처를 수정하거나 삭제해주세요.');
              }

              return SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: availableGestures.length,
                  itemBuilder: (context, index) {
                    final entry = availableGestures[index];
                    final gestureId = entry.key;

                    return GestureDetector(
                      onTap: () =>
                          _connectGestureToAction(gestureId, control, label),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              GestureService.getGestureIcon(gestureId),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              GestureService.getGestureName(gestureId),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

  void _showActionSelectionDialog(String gestureId, String gestureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$gestureName 제스처에 연결할 동작 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: SizedBox(
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _deviceActions.length,
              itemBuilder: (context, index) {
                final action = _deviceActions[index];
                final control = action['control']!;
                final label = action['label']!;

                return ListTile(
                  title: Text(label),
                  subtitle: Text(control),
                  onTap: () =>
                      _connectGestureToAction(gestureId, control, label),
                );
              },
            ),
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

  void _showGestureChangeDialog(
      String control, String label, String currentGesture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label 동작에 연결할 제스처 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('control_gesture/${widget.keyName}')
                .onValue,
            builder: (context, snapshot) {
              // 현재 사용 중인 제스처 목록 파악 (현재 제스처 제외)
              Set<String> usedGestures = {};
              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                final data =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                usedGestures = data.keys.map((k) => k.toString()).toSet();
                usedGestures.remove(currentGesture); // 현재 제스처는 변경 가능하므로 제외
              }

              // 사용 가능한 제스처 목록 (현재 제스처 포함)
              final availableGestures = _availableGestures.entries
                  .where((entry) => !usedGestures.contains(entry.key))
                  .toList();

              return SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: availableGestures.length,
                  itemBuilder: (context, index) {
                    final entry = availableGestures[index];
                    final gestureId = entry.key;
                    final isCurrentGesture = gestureId == currentGesture;

                    return GestureDetector(
                      onTap: isCurrentGesture
                          ? null
                          : () => _connectGestureToAction(
                              gestureId, control, label),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrentGesture
                              ? Colors.grey[200]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrentGesture
                                ? Colors.grey[400]!
                                : Colors.blue[200]!,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              GestureService.getGestureIcon(gestureId),
                              style: TextStyle(
                                fontSize: 14,
                                color: isCurrentGesture
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCurrentGesture
                                  ? '${GestureService.getGestureName(gestureId)}\n(현재 설정)'
                                  : GestureService.getGestureName(gestureId),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCurrentGesture
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

  Future<void> _connectGestureToAction(
      String gestureId, String control, String label) async {
    Navigator.pop(context); // 다이얼로그 닫기

    try {
      // 먼저 해당 동작에 이미 연결된 제스처가 있는지 확인 (백엔드 구조)
      final snapshot = await FirebaseDatabase.instance
          .ref(
              'control_gesture/${FirebaseAuth.instance.currentUser?.uid}/${widget.keyName}')
          .once();

      String? existingGestureId;
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          final existingControl = entry.value['control']?.toString();
          if (existingControl == control) {
            existingGestureId = entry.key.toString();
            break;
          }
        }
      }

      bool success;

      if (existingGestureId != null) {
        // 기존 제스처가 있으면 UPDATE API 사용
        print('🔄 기존 제스처 업데이트 중: $existingGestureId → $gestureId');
        success = await GestureService.updateGestureMapping(
          widget.keyName,
          gestureId,
          control,
          label,
        );
      } else {
        // 새로운 제스처 연결은 REGISTER API 사용
        print('➕ 새로운 제스처 등록 중: $gestureId');
        success = await GestureService.saveGestureMapping(
          widget.keyName,
          gestureId,
          control,
          label,
        );
      }

      if (success) {
        final gestureName = GestureService.getGestureName(gestureId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $label → $gestureName 제스처로 변경 완료!'),
            backgroundColor: Colors.green,
          ),
        );
        // StreamBuilder가 자동으로 업데이트하므로 _loadData() 제거
      } else {
        throw Exception('저장 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 제스처 연결 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteGestureMapping(
      String gestureId, String gestureName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제스처 삭제'),
        content: Text('$gestureName 제스처 설정을 삭제하시겠습니까?'),
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
        final success = await GestureService.deleteGestureMapping(
            widget.keyName, gestureId);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $gestureName 제스처 삭제 완료'),
              backgroundColor: Colors.green,
            ),
          );
          // StreamBuilder가 자동으로 업데이트하므로 _loadData() 제거
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
