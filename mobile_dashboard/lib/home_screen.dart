import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'header.dart';
import 'services/recommendation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _recommendation;
  Map<String, dynamic>? _backendRecommendations; // 백엔드 API 추천
  bool _showRecommendation = true;
  bool _isLoadingRecommendation = true;
  bool _isLoadingBackendRecommendations = false; // 백엔드 API 추천 로딩 상태
  bool _isBackendApiConnected = false; // 백엔드 API 연결 상태

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
    _loadBackendApiRecommendations(); // 백엔드 API 추천 로드
  }

  Future<void> _loadRecommendation() async {
    try {
      final rec = await RecommendationService.getBackendRecommendations();
      if (mounted) {
        setState(() {
          _recommendation = rec;
          _isLoadingRecommendation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecommendation = false;
        });
      }
    }
  }

  Future<void> _loadBackendApiRecommendations() async {
    setState(() => _isLoadingBackendRecommendations = true);

    try {
      // 백엔드 API 연결 상태 확인
      // 백엔드 연결 확인은 추천 데이터 로드에서 자동으로 처리
      final isConnected = true;

      if (isConnected) {
        final backendRecommendations =
            await RecommendationService.getBackendRecommendations();

        if (backendRecommendations != null) {
          setState(() {
            _backendRecommendations = backendRecommendations;
            _isLoadingBackendRecommendations = false;
            _isBackendApiConnected = true;
          });
        } else {
          setState(() {
            _backendRecommendations = null;
            _isLoadingBackendRecommendations = false;
            _isBackendApiConnected = false;
          });
        }
      } else {
        setState(() {
          _backendRecommendations = null;
          _isLoadingBackendRecommendations = false;
          _isBackendApiConnected = false;
        });
      }
    } catch (e) {
      setState(() {
        _backendRecommendations = null;
        _isLoadingBackendRecommendations = false;
        _isBackendApiConnected = false;
      });
    }
  }

  Widget _buildRecommendationCard() {
    // 백엔드 API 추천만 표시 (API 실패 시 카드 숨김)
    if (!_showRecommendation ||
        _recommendation == null ||
        !_isBackendApiConnected) {
      return const SizedBox.shrink();
    }

    // 백엔드 API 응답 구조에 맞게 수정
    final recommendations =
        _recommendation!['recommendations'] as List<dynamic>?;

    if (recommendations == null || recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    // 첫 번째 추천 사용
    final firstRec = recommendations.first as Map<String, dynamic>;
    final device = firstRec['device'] as String? ?? '';
    final gesture = firstRec['recommended_gesture'] as String?;
    final voice = firstRec['recommended_voice'] as String?;
    final reason = firstRec['reason'] as String? ?? '';

    final title = gesture != null
        ? '🤚 ${_getDeviceName(device)} 제스처 추천'
        : '🎤 ${_getDeviceName(device)} 음성 추천';
    final message = gesture != null
        ? '$gesture 제스처로 ${_getDeviceName(device)}을(를) 제어해보세요'
        : '"$voice"로 ${_getDeviceName(device)}을(를) 제어해보세요';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: gesture != null ? Colors.purple.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gesture != null
                    ? Colors.purple.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                gesture != null ? Icons.back_hand : Icons.mic,
                color: gesture != null
                    ? Colors.purple.shade700
                    : Colors.blue.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '💡 $reason',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/recommendation');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.blue.shade100,
                    ),
                    child: Text(
                      '자세히 보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _showRecommendation = false;
                });
              },
              icon: Icon(
                Icons.close,
                color: Colors.grey.shade600,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendRecommendationsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '🤖 AI 추천',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingBackendRecommendations)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _loadBackendApiRecommendations,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.purple.shade700,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '새로고침',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingBackendRecommendations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'AI 추천을 불러오는 중...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (_backendRecommendations == null ||
                _backendRecommendations!['recommendations'] == null ||
                _backendRecommendations!['recommendations']!.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning,
                            color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Python 서버에 연결할 수 없습니다',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Python Flask 서버가 실행되지 않았습니다\n'
                      '• ngrok 터널이 활성화되지 않았습니다\n'
                      '• 샘플 데이터로 테스트 중입니다',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loadBackendApiRecommendations,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('다시 시도'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[100],
                        foregroundColor: Colors.orange[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // API 상태 표시 (실제 데이터 vs 샘플 데이터)
                  Builder(
                    builder: (context) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isBackendApiConnected
                              ? Colors.green[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isBackendApiConnected
                                ? Colors.green[200]!
                                : Colors.blue[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isBackendApiConnected
                                  ? Icons.check_circle
                                  : Icons.code,
                              color: _isBackendApiConnected
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isBackendApiConnected
                                  ? '🤖 실시간 AI 추천 연결됨'
                                  : '🧪 샘플 데이터로 테스트 중',
                              style: TextStyle(
                                color: _isBackendApiConnected
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isBackendApiConnected
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isBackendApiConnected ? 'LIVE' : 'TEST',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 추천 목록
                  ...(_backendRecommendations!['recommendations']
                              as List<dynamic>?)
                          ?.map((recommendation) {
                        // 백엔드 API 응답 형식에 맞게 데이터 추출
                        final device = recommendation['device'] ?? '';
                        final recommendedGesture =
                            recommendation['recommended_gesture'];
                        final recommendedVoice =
                            recommendation['recommended_voice'];
                        final reason = recommendation['reason'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey[200]!,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: recommendedGesture != null
                                          ? Colors.blue
                                          : Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      recommendedGesture != null
                                          ? Icons.gesture
                                          : Icons.mic,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (recommendedGesture != null) ...[
                                          Text(
                                            '🎯 제스처 추천: $device',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '추천 제스처: $recommendedGesture',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ] else if (recommendedVoice !=
                                            null) ...[
                                          Text(
                                            '🎤 음성 추천: $device',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '추천 음성: $recommendedVoice',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[25],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.purple[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            color: Colors.purple[700],
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList() ??
                      [],
                ],
              ),
            if (_backendRecommendations != null &&
                _backendRecommendations!['recommendations'] != null &&
                _backendRecommendations!['recommendations']!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/recommendation');
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.purple.shade100,
                  ),
                  child: Text(
                    '더 많은 추천 보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance;

    return SafeArea(
      child: Column(
        children: [
          const Header(),

          // 추천 카드 (로딩 중일 때는 보여주지 않음)
          if (!_isLoadingRecommendation) _buildRecommendationCard(),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    '현재 연결된 기기 모드',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 기기 정보 표시 (사진, 이름, 최근 손동작)
                  Container(
                    constraints: const BoxConstraints(minHeight: 300),
                    child: StreamBuilder<DatabaseEvent>(
                      stream: db
                          .ref(
                              'user_info/${FirebaseAuth.instance.currentUser?.uid}')
                          .onValue,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data?.snapshot.value == null ||
                            snapshot.data?.snapshot.value.toString().isEmpty ==
                                true) {
                          return Column(
                            children: const [
                              Icon(Icons.device_unknown,
                                  size: 100, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                '연결된 기기가 없습니다',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          );
                        }

                        final value = snapshot.data!.snapshot.value
                            as Map<dynamic, dynamic>;
                        final currentDevice =
                            value['current_device']?.toString() ?? '';
                        final lastGesture =
                            value['last_gesture']?.toString() ?? '';
                        final updatedAt = value['updatedAt']?.toString() ?? '';

                        // 현재 기기가 설정되어 있는지 확인 (null 문자열 포함)
                        if (currentDevice.isEmpty || currentDevice == "null") {
                          return Column(
                            children: [
                              // 스마트폰 형태의 물음표 아이콘
                              Container(
                                width: 100,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.help_outline,
                                          size: 50,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '연결된 기기가 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 연결 안됨 상태
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        size: 8, color: Colors.red[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      '연결 안됨',
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // 기기 정보 표시
                        return Column(
                          children: [
                            // 기기 이미지 (PNG 파일) 또는 기본 물음표 박스
                            SizedBox(
                              width: 150,
                              height: 200,
                              child: Image.asset(
                                'assets/icons/${currentDevice}.png',
                                width: 120,
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // PNG 파일이 없으면 스마트폰 형태 물음표 박스 표시
                                  return _buildDefaultDeviceIcon();
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 기기 이름 (한글)
                            Text(
                              _getDeviceName(currentDevice),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 기기 상태
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (currentDevice.isEmpty ||
                                        currentDevice == "null")
                                    ? Colors.red[100]
                                    : Colors.green[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 8,
                                      color: (currentDevice.isEmpty ||
                                              currentDevice == "null")
                                          ? Colors.red[600]
                                          : Colors.green[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    (currentDevice.isEmpty ||
                                            currentDevice == "null")
                                        ? '연결 안됨'
                                        : '연결됨',
                                    style: TextStyle(
                                      color: (currentDevice.isEmpty ||
                                              currentDevice == "null")
                                          ? Colors.red[700]
                                          : Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 최근 인식한 손동작 (영어 원본)
                            if (lastGesture.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '🤚 최근 인식한 손동작: $lastGesture',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],

                            // 업데이트 시간
                            if (updatedAt.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                '마지막 업데이트: ${_formatTime(updatedAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  // AI 추천을 스크롤해야 보이도록 큰 공백 추가
                  const SizedBox(height: 200),

                  // API 추천 섹션
                  _buildBackendRecommendationsSection(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 기본 기기 아이콘 (스마트폰 형태 물음표 박스)
  Widget _buildDefaultDeviceIcon() {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                Icons.help_outline,
                size: 45,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 기기별 아이콘 반환
  String _getDeviceIcon(String device) {
    switch (device.toLowerCase()) {
      case 'light':
        return '💡';
      case 'fan':
        return '🌀';
      case 'tv':
        return '📺';
      case 'airconditioner':
      case 'ac':
        return '❄️';

      case 'curtain':
        return '🪟';
      case 'projector':
        return '📽️';
      default:
        return '🏠';
    }
  }

  // 기기별 색상 반환
  Color _getDeviceColor(String device) {
    switch (device.toLowerCase()) {
      case 'light':
        return Colors.amber[100]!;
      case 'fan':
        return Colors.blue[100]!;
      case 'tv':
        return Colors.indigo[100]!;
      case 'airconditioner':
      case 'ac':
        return Colors.cyan[100]!;

      case 'curtain':
        return Colors.brown[100]!;
      case 'projector':
        return Colors.purple[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  // 기기명 한글 변환
  String _getDeviceName(String device) {
    switch (device.toLowerCase()) {
      case 'light':
        return '전등';
      case 'fan':
        return '선풍기';
      case 'tv':
        return 'TV';
      case 'airconditioner':
      case 'ac':
        return '에어컨';

      case 'curtain':
        return '커튼';
      case 'projector':
        return '프로젝터';
      default:
        return device;
    }
  }

  // 제스처명 반환
  String _getGestureName(String gesture) {
    const gestureNames = {
      'one': '1️⃣ 손가락 하나',
      'two': '2️⃣ 손가락 둘',
      'three': '3️⃣ 손가락 셋',
      'four': '4️⃣ 손가락 넷',
      'five': '5️⃣ 손가락 다섯',
      'peace': '✌️ 브이',
      'thumbs_up': '👍 따봉',
      'thumbs_down': '👎 따봉 하',
      'small_heart': '💜 작은 하트',
      'spider_man': '🕷️ 스파이더맨',
      'promise': '🤙 약속',
      'thumbs_left': '👈 왼쪽 가리키기',
      'vertical_V': '🖖 수직 브이',
      'clockwise': '🔄 시계방향',
      'counter_clockwise': '🔄 반시계방향',
      'ok': '👌 오케이',
      'gun': '🔫 총'
    };
    return gestureNames[gesture] ?? gesture;
  }

  // 시간 포맷팅
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return isoString;
    }
  }
}
