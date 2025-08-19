import 'package:flutter/material.dart';
import '../services/recommendation_service.dart';
import '../header.dart';

class UsageAnalyticsScreen extends StatefulWidget {
  const UsageAnalyticsScreen({super.key});

  @override
  State<UsageAnalyticsScreen> createState() => _UsageAnalyticsScreenState();
}

class _UsageAnalyticsScreenState extends State<UsageAnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics = await RecommendationService.analyzeUserPatterns();
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로딩 실패: $e')),
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
                  const Text(
                    '사용 통계',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadAnalytics,
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _analytics == null
                      ? const Center(
                          child: Text('데이터를 불러올 수 없습니다'),
                        )
                      : _buildAnalyticsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final deviceUsage = _analytics!['deviceUsage'] as Map<String, int>? ?? {};
    final commandUsage = _analytics!['commandUsage'] as Map<String, int>? ?? {};
    final timePatterns = _analytics!['timePatterns'] as Map<String, int>? ?? {};
    final sourceUsage = _analytics!['sourceUsage'] as Map<String, int>? ?? {};
    final totalLogs = _analytics!['totalLogs'] as int? ?? 0;
    final patternScore = _analytics!['patternScore'] as double? ?? 0.0;
    final dataSource = _analytics!['dataSource'] as String? ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전체 통계 카드
          _buildStatCard(
            '전체 사용량',
            '$totalLogs회',
            '데이터 소스: $dataSource',
            Icons.analytics,
            Colors.blue,
          ),
          const SizedBox(height: 16),

          // 기기별 사용량
          _buildSectionTitle('기기별 사용량'),
          if (deviceUsage.isEmpty)
            _buildEmptyState('기기 사용 데이터가 없습니다')
          else
            ...deviceUsage.entries.map((entry) => _buildUsageItem(
                  _getDeviceName(entry.key),
                  entry.value,
                  totalLogs > 0 ? entry.value / totalLogs : 0.0,
                  _getDeviceIcon(entry.key),
                )),

          const SizedBox(height: 24),

          // 명령별 사용량
          _buildSectionTitle('명령별 사용량'),
          if (commandUsage.isEmpty)
            _buildEmptyState('명령 사용 데이터가 없습니다')
          else
            ...commandUsage.entries.map((entry) => _buildUsageItem(
                  _getCommandLabel(entry.key),
                  entry.value,
                  totalLogs > 0 ? entry.value / totalLogs : 0.0,
                  _getCommandIcon(entry.key),
                )),

          const SizedBox(height: 24),

          // 출처별 사용량
          _buildSectionTitle('제어 방식별 사용량'),
          if (sourceUsage.isEmpty)
            _buildEmptyState('제어 방식 데이터가 없습니다')
          else
            ...sourceUsage.entries.map((entry) => _buildUsageItem(
                  _getSourceLabel(entry.key),
                  entry.value,
                  totalLogs > 0 ? entry.value / totalLogs : 0.0,
                  _getSourceIcon(entry.key),
                )),

          const SizedBox(height: 24),

          // 시간대별 사용 패턴
          _buildSectionTitle('시간대별 사용 패턴'),
          if (timePatterns.isEmpty)
            _buildEmptyState('시간대 사용 데이터가 없습니다')
          else
            ...timePatterns.entries.map((entry) => _buildUsageItem(
                  entry.key,
                  entry.value,
                  totalLogs > 0 ? entry.value / totalLogs : 0.0,
                  _getTimeIcon(entry.key),
                )),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUsageItem(
      String name, int count, double percentage, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(name),
        subtitle: Text('${(percentage * 100).toStringAsFixed(1)}%'),
        trailing: Text(
          '${count}회',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDeviceName(String deviceId) {
    const deviceNames = {
      'light': '전등',
      'fan': '선풍기',
      'tv': '텔레비전',
      'curtain': '커튼',
      'projector': '빔프로젝터',
    };
    return deviceNames[deviceId] ?? deviceId;
  }

  IconData _getDeviceIcon(String deviceId) {
    const deviceIcons = {
      'light': Icons.lightbulb_outline,
      'fan': Icons.air,
      'tv': Icons.tv,
      'curtain': Icons.curtains,
      'projector': Icons.videocam,
    };
    return deviceIcons[deviceId] ?? Icons.device_unknown;
  }

  String _getCommandLabel(String command) {
    const commandLabels = {
      'power': '전원',
      'vol_up': '볼륨 올리기',
      'vol_down': '볼륨 내리기',
      'channel_up': '채널 올리기',
      'channel_down': '채널 내리기',
      'menu': '메뉴',
      'home': '홈',
      'back': '뒤로',
      'ok': '확인',
      'mute': '음소거',
      'brighter': '밝게',
      'dimmer': '어둡게',
    };
    return commandLabels[command] ?? command;
  }

  IconData _getCommandIcon(String command) {
    const commandIcons = {
      'power': Icons.power_settings_new,
      'vol_up': Icons.volume_up,
      'vol_down': Icons.volume_down,
      'channel_up': Icons.keyboard_arrow_up,
      'channel_down': Icons.keyboard_arrow_down,
      'menu': Icons.menu,
      'home': Icons.home,
      'back': Icons.arrow_back,
      'ok': Icons.check_circle,
      'mute': Icons.volume_off,
      'brighter': Icons.brightness_high,
      'dimmer': Icons.brightness_low,
    };
    return commandIcons[command] ?? Icons.settings_remote;
  }

  String _getSourceLabel(String source) {
    const sourceLabels = {
      'mobile_app': '앱 직접 제어',
      'gesture': '제스처 제어',
      'voice': '음성 제어',
      'schedule': '스케줄 제어',
      'automation': '자동화',
    };
    return sourceLabels[source] ?? source;
  }

  IconData _getSourceIcon(String source) {
    const sourceIcons = {
      'mobile_app': Icons.smartphone,
      'gesture': Icons.gesture,
      'voice': Icons.mic,
      'schedule': Icons.schedule,
      'automation': Icons.auto_mode,
    };
    return sourceIcons[source] ?? Icons.settings;
  }

  IconData _getTimeIcon(String timeSlot) {
    const timeIcons = {
      '아침': Icons.wb_sunny,
      '오후': Icons.wb_sunny_outlined,
      '저녁': Icons.nights_stay_outlined,
      '밤': Icons.nightlight_round,
    };
    return timeIcons[timeSlot] ?? Icons.access_time;
  }
}
