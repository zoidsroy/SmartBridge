import 'package:flutter/material.dart';
import '../header.dart';
import '../services/recommendation_service.dart';
import '../services/backend_api_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  Map<String, dynamic>? _userPatterns;
  Map<String, dynamic>? _dailyStats;
  Map<String, dynamic>? _backendRecommendations; // 백엔드 API에서 받은 추천
  bool _isLoading = true;
  bool _isApiLoading = false; // API 로딩 상태
  String _selectedTab = '분석';

  @override
  void initState() {
    super.initState();
    _loadRecommendationData();
  }

  Future<void> _loadRecommendationData() async {
    setState(() => _isLoading = true);

    try {
      print('📊 추천 데이터 로딩 시작...');

      // 기존 로컬 데이터 로딩
      await _loadLocalData();

      // 백엔드 API 추천 데이터 로딩 (병렬 실행)
      _loadBackendApiRecommendations();
    } catch (e) {
      print('❌ 전체 데이터 로딩 실패: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadLocalData() async {
    // 사용자 패턴 분석 (로컬만)
    Map<String, dynamic> patterns;
    try {
      print('📊 사용자 패턴 분석 중...');
      patterns = await RecommendationService.analyzeUserPatterns();
      print('📊 패턴 분석 완료: ${patterns['totalLogs']}개 로그');
    } catch (e) {
      print('⚠️ 패턴 분석 실패: $e');
      patterns = {
        'deviceUsage': <String, int>{},
        'commandUsage': <String, int>{},
        'timePatterns': <String, int>{},
        'sourceUsage': <String, int>{},
        'totalLogs': 0,
        'patternScore': 0.0,
        'analysisDate': DateTime.now().toIso8601String(),
        'recommendations': ['더 많은 기기를 사용해보세요!'],
      };
    }

    // 일별 통계 (로컬만)
    Map<String, dynamic> dailyStats;
    try {
      print('📅 일별 통계 로딩 중...');
      dailyStats = await RecommendationService.getDailyStats();
      print('📅 일별 통계 완료');
    } catch (e) {
      print('⚠️ 일별 통계 실패: $e');
      dailyStats = {
        'dailyStats': <String, Map<String, int>>{},
        'totalDays': 0,
      };
    }

    setState(() {
      _userPatterns = patterns;
      _dailyStats = dailyStats;
      _isLoading = false;
    });

    print('✅ 로컬 데이터 로딩 완료');
  }

  Future<void> _loadBackendApiRecommendations() async {
    setState(() => _isApiLoading = true);

    try {
      print('🔗 백엔드 API 추천 데이터 로딩 시작...');

      final backendRecommendations =
          await RecommendationService.getBackendRecommendations();

      if (backendRecommendations != null) {
        setState(() {
          _backendRecommendations = backendRecommendations;
          _isApiLoading = false;
        });
        print(
            '✅ 백엔드 API 추천 데이터 로딩 완료: ${backendRecommendations['recommendations']?.length ?? 0}개');
      } else {
        throw Exception('백엔드 API 응답이 null입니다');
      }
    } catch (e) {
      print('❌ 백엔드 API 추천 데이터 로딩 실패: $e');
      setState(() {
        _backendRecommendations = null;
        _isApiLoading = false;
      });

      // 에러는 표시하지만 앱은 계속 동작
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔗 백엔드 API 추천 로드 실패: 로컬 추천을 사용합니다'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 사용 패턴 & 추천',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 탭 버튼들
                  Row(
                    children: [
                      _buildTabButton('분석'),
                      const SizedBox(width: 8),
                      _buildTabButton('추천'),
                      const SizedBox(width: 8),
                      _buildTabButton('통계'),
                      const Spacer(),
                      // 테스트 데이터 생성 버튼
                      IconButton(
                        onPressed: _createSampleData,
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.orange),
                        tooltip: '테스트 데이터 생성',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTabContent(),
            ),
          ],
        ),
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
      case 'projector':
        return '📽️';
      case 'curtain':
        return '🪟';
      case 'tv':
        return '📺';
      default:
        return '🏠';
    }
  }

  // 기기명 한글 변환
  String _getDeviceName(String device) {
    switch (device.toLowerCase()) {
      case 'light':
        return '전등';
      case 'fan':
        return '선풍기';
      case 'projector':
        return '프로젝터';
      case 'curtain':
        return '커튼';
      case 'tv':
        return 'TV';
      default:
        return device;
    }
  }

  Widget _buildTabButton(String title) {
    final isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case '분석':
        return _buildAnalysisTab();
      case '추천':
        return _buildRecommendationTab();
      case '통계':
        return _buildStatsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAnalysisTab() {
    if (_userPatterns == null) {
      return const Center(child: Text('데이터가 없습니다'));
    }

    final patterns = _userPatterns!;
    final deviceUsage = patterns['deviceUsage'] as Map<String, int>? ?? {};
    final gestureUsage = patterns['gestureUsage'] as Map<String, int>? ?? {};
    final timePatterns = patterns['timePatterns'] as Map<String, int>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 요약 카드
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎯 사용 패턴 요약',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                    '가장 많이 사용하는 기기', patterns['mostUsedDevice']?.toString()),
                _buildSummaryRow(
                    '선호하는 제스처', patterns['mostUsedGesture']?.toString()),
                _buildSummaryRow(
                    '주로 사용하는 시간', patterns['favoriteTime']?.toString()),
                _buildSummaryRow('총 로그 수', '${patterns['totalLogs'] ?? 0}개'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 기기 사용량
        if (deviceUsage.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📱 기기별 사용량',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...deviceUsage.entries.map((entry) => _buildUsageBar(
                      entry.key,
                      entry.value,
                      deviceUsage.values.reduce((a, b) => a > b ? a : b))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 제스처 사용량
        if (gestureUsage.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✋ 제스처별 사용량',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...gestureUsage.entries.map((entry) => _buildUsageBar(
                      _getGestureName(entry.key),
                      entry.value,
                      gestureUsage.values.reduce((a, b) => a > b ? a : b))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 시간대 패턴
        if (timePatterns.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🕐 시간대별 사용 패턴',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...timePatterns.entries.map((entry) => _buildUsageBar(
                      entry.key,
                      entry.value,
                      timePatterns.values.reduce((a, b) => a > b ? a : b))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendationTab() {
    final localRecommendations =
        _userPatterns?['recommendations'] as List<String>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 헤더 카드
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      '개인화된 추천',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // API 연결 테스트 버튼
                    IconButton(
                      onPressed: _testApiConnection,
                      icon: const Icon(Icons.wifi_find, color: Colors.blue),
                      tooltip: 'API 연결 테스트',
                    ),
                    // 새로고침 버튼
                    IconButton(
                      onPressed: _refreshApiRecommendations,
                      icon: const Icon(Icons.refresh, color: Colors.green),
                      tooltip: '추천 새로고침',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '🤖 AI 기반 실시간 추천과 📊 사용 패턴 기반 추천을 제공합니다',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // API 추천 섹션
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '🤖 AI 실시간 추천',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_isApiLoading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (_isApiLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('AI 추천을 불러오는 중...'),
                    ),
                  )
                else if (_backendRecommendations == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '스마트홈 제스처 시스템',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        if (_userPatterns != null &&
                            _userPatterns!['welcomeMessage'] != null)
                          Text(
                            _userPatterns!['welcomeMessage'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        SizedBox(height: 12),
                        if (_userPatterns != null &&
                            _userPatterns!['nextSteps'] != null)
                          ...(_userPatterns!['nextSteps'] as List<dynamic>).map(
                            (step) => Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 16)),
                                  Expanded(
                                    child: Text(
                                      step.toString(),
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else if (_backendRecommendations!['recommendations'] == null ||
                    (_backendRecommendations!['recommendations']
                            as List<dynamic>?)!
                        .isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI가 분석할 수 있는 데이터가 부족합니다. 더 사용해보세요!',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...(_backendRecommendations!['recommendations']
                          as List<dynamic>?)!
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final recommendation = entry.value;

                    // 백엔드 API 응답 형식에 맞게 데이터 추출
                    final device = recommendation['device'] ?? '';
                    final recommendedGesture =
                        recommendation['recommended_gesture'];
                    final recommendedVoice =
                        recommendation['recommended_voice'];
                    final reason = recommendation['reason'] ?? '';

                    // 제스처 추천인지 음성 추천인지 확인
                    final isGestureRecommendation = recommendedGesture != null;
                    final isVoiceRecommendation = recommendedVoice != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isGestureRecommendation
                            ? Colors.purple[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isGestureRecommendation
                              ? Colors.purple[100]!
                              : Colors.blue[100]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // 기기 아이콘
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isGestureRecommendation
                                      ? Colors.purple[100]
                                      : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    _getDeviceIcon(device),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 추천 타입 아이콘
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isGestureRecommendation
                                      ? Colors.purple
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    isGestureRecommendation
                                        ? Icons.back_hand
                                        : Icons.mic,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (recommendedGesture != null) ...[
                                      Text(
                                        '${_getDeviceName(device)} 제스처 추천',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.purple[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '🤚 $recommendedGesture',
                                          style: TextStyle(
                                            color: Colors.purple[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ] else if (recommendedVoice != null) ...[
                                      Text(
                                        '${_getDeviceName(device)} 음성 추천',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '🎤 "$recommendedVoice"',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (reason.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 14,
                                            color: Colors.amber[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              reason,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 로컬 추천 섹션
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '📊 사용 패턴 기반 추천',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (localRecommendations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty,
                            color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '아직 충분한 사용 데이터가 없습니다. 더 사용해보세요!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...localRecommendations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final recommendation = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              recommendation,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // API 연결 테스트
  Future<void> _testApiConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('API 연결을 테스트하는 중...'),
          ],
        ),
      ),
    );

    try {
      final isConnected = await BackendApiService.testConnection();

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(isConnected ? 'API 연결 성공' : 'API 연결 실패'),
              ],
            ),
            content: Text(
              isConnected
                  ? '🎉 API 서버에 성공적으로 연결되었습니다!\n실시간 추천 기능을 사용할 수 있습니다.'
                  : '❌ API 서버에 연결할 수 없습니다.\n- ngrok 서버가 실행 중인지 확인해주세요\n- URL이 올바른지 확인해주세요\n\nURL: ${BackendApiService.apiUrl}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('연결 테스트 중 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // API 추천 새로고침
  Future<void> _refreshApiRecommendations() async {
    await _loadBackendApiRecommendations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _backendRecommendations != null &&
                    _backendRecommendations!['recommendations'] != null &&
                    (_backendRecommendations!['recommendations']
                            as List<dynamic>?)!
                        .isNotEmpty
                ? '✅ 추천 데이터가 업데이트되었습니다 (${(_backendRecommendations!['recommendations'] as List<dynamic>?)!.length}개)'
                : '⚠️ 추천 데이터를 불러올 수 없습니다',
          ),
          backgroundColor: _backendRecommendations != null &&
                  _backendRecommendations!['recommendations'] != null &&
                  (_backendRecommendations!['recommendations']
                          as List<dynamic>?)!
                      .isNotEmpty
              ? Colors.green
              : Colors.orange,
        ),
      );
    }
  }

  Widget _buildStatsTab() {
    if (_dailyStats == null) {
      return const Center(child: Text('통계 데이터가 없습니다'));
    }

    final dailyStats =
        _dailyStats!['dailyStats'] as Map<String, dynamic>? ?? {};
    final totalDays = _dailyStats!['totalDays'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📈 일별 사용 통계',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '총 $totalDays일간의 사용 기록',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (dailyStats.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('일별 통계 데이터가 없습니다'),
            ),
          )
        else
          ...dailyStats.entries.map((dateEntry) {
            final date = dateEntry.key;
            final deviceData = dateEntry.value as Map<String, int>;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(date),
                subtitle:
                    Text('${deviceData.values.fold(0, (a, b) => a + b)}회 사용'),
                children: deviceData.entries.map((deviceEntry) {
                  return ListTile(
                    dense: true,
                    title: Text(deviceEntry.key),
                    trailing: Text('${deviceEntry.value}회'),
                  );
                }).toList(),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value?.isEmpty == true || value == null ? '데이터 없음' : value!,
              style: const TextStyle(color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildUsageBar(String label, int value, int maxValue) {
    final percentage = maxValue > 0 ? value / maxValue : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$value회'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ),
    );
  }

  String _getGestureName(String gesture) {
    const gestureNames = {
      'thumbs_up': '👍 좋아요',
      'swipe_up': '👆 위로 스와이프',
      'swipe_down': '👇 아래로 스와이프',
      'circle': '⭕ 원 그리기',
      'pinch': '👌 핀치',
    };
    return gestureNames[gesture] ?? gesture;
  }

  Future<void> _createSampleData() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('테스트 데이터 생성 중...'),
            ],
          ),
        ),
      );

      // 샘플 데이터 생성
      await RecommendationService.createSampleLogData();

      // 로딩 닫기
      if (mounted) Navigator.pop(context);

      // 데이터 새로고침
      await _loadRecommendationData();

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 테스트 데이터가 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) Navigator.pop(context);

      // 오류 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 테스트 데이터 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
