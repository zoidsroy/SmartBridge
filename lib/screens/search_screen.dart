import 'package:flutter/material.dart';
import '../header.dart';
import '../services/device_service.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;

  final List<SearchResult> _allItems = [
    // 기기 관리 관련
    SearchResult(
      title: '기기 추가',
      subtitle: '새로운 스마트 기기 연결',
      category: '기기 관리',
      icon: Icons.add_circle_outline,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'add_device'},
    ),
    SearchResult(
      title: '기기 이름 변경',
      subtitle: '등록된 기기 이름 수정',
      category: '기기 관리',
      icon: Icons.edit,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'rename_device'},
    ),

    // 기능 관련
    SearchResult(
      title: '모드 진입 제스처 설정',
      subtitle: '기기별 모드 진입 제스처 커스터마이징',
      category: '기능',
      icon: Icons.touch_app,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'mode_gesture_customization'},
    ),
    SearchResult(
      title: '제스쳐 설정',
      subtitle: '기기별 제어 제스처 커스터마이징',
      category: '기능',
      icon: Icons.gesture,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'gesture_customization'},
    ),
    SearchResult(
      title: '사용 통계',
      subtitle: '기기 사용량 분석 및 추천',
      category: '기능',
      icon: Icons.analytics,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'usage_analytics'},
    ),
    SearchResult(
      title: '개인화 추천',
      subtitle: '사용 패턴 분석 및 맞춤형 추천',
      category: '기능',
      icon: Icons.recommend,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'recommendation'},
    ),
    SearchResult(
      title: '기기 추가',
      subtitle: '새로운 스마트 기기 연결',
      category: '기능',
      icon: Icons.add_circle_outline,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'add_device'},
    ),
    SearchResult(
      title: '기기 이름 변경',
      subtitle: '등록된 기기 이름 수정',
      category: '기능',
      icon: Icons.edit,
      action: SearchAction.navigateToFunction,
      actionData: {'function': 'rename_device'},
    ),

    // 도움말 관련
    SearchResult(
      title: '제스쳐 사용법',
      subtitle: '손동작 인식 방법 안내',
      category: '도움말',
      icon: Icons.help_outline,
      action: SearchAction.showHelp,
      actionData: {'helpType': 'gesture_guide'},
    ),
    SearchResult(
      title: '앱 사용법',
      subtitle: '전체 앱 기능 설명',
      category: '도움말',
      icon: Icons.info_outline,
      action: SearchAction.showHelp,
      actionData: {'helpType': 'app_guide'},
    ),
    SearchResult(
      title: '문제 해결',
      subtitle: '자주 묻는 질문 및 해결 방법',
      category: '도움말',
      icon: Icons.build,
      action: SearchAction.showHelp,
      actionData: {'helpType': 'troubleshooting'},
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(_allItems);

    // 초기 검색어가 있으면 설정하고 검색 실행
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _performSearch(widget.initialQuery);
    }
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        _searchResults = List.from(_allItems);
      } else {
        _searchResults = _allItems.where((item) {
          return item.title.toLowerCase().contains(query.toLowerCase()) ||
              item.subtitle.toLowerCase().contains(query.toLowerCase()) ||
              item.category.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
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
                    '검색',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '기기나 기능을 검색하세요...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: _performSearch,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '다른 키워드로 검색해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 카테고리별로 그룹화
    final groupedResults = <String, List<SearchResult>>{};
    for (final result in _searchResults) {
      groupedResults.putIfAbsent(result.category, () => []).add(result);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedResults.length,
      itemBuilder: (context, index) {
        final category = groupedResults.keys.elementAt(index);
        final items = groupedResults[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            ...items.map((item) => _buildSearchResultItem(item)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor(result.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            result.icon,
            color: _getCategoryColor(result.category),
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(result.subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _handleSearchResult(result),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '기기':
        return Colors.blue;
      case '기능':
        return Colors.green;
      case '도움말':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _handleSearchResult(SearchResult result) {
    switch (result.action) {
      case SearchAction.navigateToDevice:
        Navigator.pushNamed(
          context,
          '/device_detail_screen',
          arguments: result.actionData,
        );
        break;

      case SearchAction.navigateToFunction:
        final function = result.actionData['function'];
        switch (function) {
          case 'mode_gesture_customization':
            _showModeGestureDeviceSelectionDialog();
            break;
          case 'gesture_customization':
            _showDeviceSelectionDialog();
            break;
          case 'usage_analytics':
            Navigator.pushNamed(context, '/usage_analytics');
            break;
          case 'recommendation':
            Navigator.pushNamed(context, '/recommendation');
            break;
          case 'add_device':
            _showAddDeviceDialog();
            break;
          case 'rename_device':
            _showRenameDeviceDialog();
            break;
        }
        break;

      case SearchAction.showHelp:
        _showHelpDialog(result.actionData['helpType']);
        break;
    }
  }

  void _showModeGestureDeviceSelectionDialog() {
    // 기기 이름 -> 기기 ID 매핑
    final deviceMapping = {
      '전등': 'light',
      'TV': 'tv',
      '커튼': 'curtain',
      '선풍기': 'fan',
      '에어컨': 'ac',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모드 진입 제스처 설정할 기기 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: deviceMapping.entries.map((entry) {
            final deviceName = entry.key;
            final deviceId = entry.value;

            return ListTile(
              leading: const Icon(Icons.touch_app),
              title: Text(deviceName),
              subtitle: Text('ID: $deviceId'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/mode_gesture_customization',
                  arguments: {
                    'keyName': deviceId, // 올바른 기기 ID 전달
                    'deviceName': deviceName, // 기기 표시명 전달
                  },
                );
              },
            );
          }).toList(),
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

  void _showDeviceSelectionDialog() {
    // 기기 이름 -> 기기 ID 매핑
    final deviceMapping = {
      '전등': 'light',
      'TV': 'tv',
      '커튼': 'curtain',
      '선풍기': 'fan',
      '에어컨': 'ac',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: deviceMapping.entries.map((entry) {
            final deviceName = entry.key;
            final deviceId = entry.value;

            return ListTile(
              leading: const Icon(Icons.devices),
              title: Text(deviceName),
              subtitle: Text('ID: $deviceId'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/gesture_customization',
                  arguments: {
                    'keyName': deviceId, // 올바른 기기 ID 전달
                    'deviceName': deviceName, // 기기 표시명 전달
                  },
                );
              },
            );
          }).toList(),
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

  void _showHelpDialog(String helpType) {
    String title = '';
    String content = '';

    switch (helpType) {
      case 'gesture_guide':
        title = '제스쳐 사용법';
        content = '''
📱 기본 제스쳐 안내:

• one: 검지를 사용하여 숫자 1을 표시하세요
• two: 검지와 중지를 사용하여 숫자 2를 표시하세요
• three: 엄지, 검지, 중지 또는 검지, 중지, 약지를 사용하여 숫자 3을 표시하세요
• four: 엄지손가락을 제외한 나머지 손가락을 사용하여 숫자 4를 표시하세요
• thumbs_up: 엄지를 사용하여 따봉 표시를 하세요
• thumbs_down: 엄지를 땅으로 향하게 하세요
• thumbs_right: 엄지를 오른쪽으로 향하게 하세요
• thumbs_left: 엄지를 왼쪽으로 향하게 하세요
• ok: 엄지와 검지를 사용해서 ok 표시를 만드세요
• promise: 엄지와 새끼손가락을 사용해서 약속 표시를 만드세요
• clockwise: 손가락을 시계방향으로 회전시키세요
• counter_clockwise: 손가락을 반시계방향으로 회전시키세요
• slide_left: 손바닥을 왼쪽으로 슬라이드하세요
• slide_right: 손바닥을 오른쪽으로 슬라이드하세요
• spider_man: 중지와 약지를 접어 스파이더맨의 손모양을 만드세요
• small_heart: 엄지와 검지를 사용해 하트 표시를 만드세요
• vertical_V: 엄지와 검지를 사용해 검지가 하늘을 향하도록 'ㄴ'을 만드세요
• horizontal_V: 엄지와 검지를 사용해 엄지가 하늘을 향하도록록 'ㄴ'을 만드세요

💡 팁:
- 카메라로부터 50cm-1m 거리에서 사용하세요
- 조명이 충분한 곳에서 사용하세요
- 손 전체가 화면에 보이도록 하세요
        ''';
        break;

      case 'app_guide':
        title = '앱 사용법';
        content = '''
🏠 Smart Bridge 사용 가이드:

1️⃣ 홈 화면
- 전체 기기 상태를 한눈에 확인
- 즐겨찾는 기기 빠른 
- 사용자에게 추천 동작 표시시

2️⃣ 기기 화면  
- 연결된 모든 기기 목록
- 각 기기별 상세 제어

3️⃣ 설정 화면
- 기기 추가/삭제
- 이름 변경
- 앱 설정

🎯 주요 기능:
- 제스쳐 커스터마이징
- 사용 패턴 분석
- 루틴 추천
        ''';
        break;

      case 'troubleshooting':
        title = '문제 해결';
        content = '''
🔧 자주 묻는 질문:

Q: 제스쳐가 인식되지 않아요
A: 조명 확인, 거리 조절, 손 전체가 보이는지 확인

Q: 기기가 연결되지 않아요  
A: WiFi 연결 상태, 기기 전원 상태 확인

Q: 앱이 느려요
A: 앱 재시작, 캐시 삭제, 최신 버전 업데이트

Q: 제스쳐 설정을 초기화하고 싶어요
A: 설정 > 기기 이름 변경에서 초기화 가능

📞 추가 문의: 
정성이조 개발팀으로 연락주세요
        ''';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
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

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('새로운 스마트 기기를 추가할 수 있습니다.'),
            const SizedBox(height: 16),
            const Text('지원되는 기기:'),
            const SizedBox(height: 8),
            ...([
              {'name': '전등', 'id': 'light', 'icon': Icons.lightbulb_outline},
              {'name': 'TV', 'id': 'tv', 'icon': Icons.tv},
              {'name': '커튼', 'id': 'curtain', 'icon': Icons.curtains},
              {'name': '선풍기', 'id': 'fan', 'icon': Icons.air},
              {'name': '에어컨', 'id': 'ac', 'icon': Icons.ac_unit},
            ].map((device) => ListTile(
                  leading: Icon(device['icon'] as IconData),
                  title: Text(device['name'] as String),
                  subtitle: Text('ID: ${device['id']}'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () {
                    Navigator.pop(context);
                    _addDevice(
                        device['id'] as String, device['name'] as String);
                  },
                ))),
          ],
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

  void _showRenameDeviceDialog() {
    final deviceMapping = {
      'light': '전등',
      'tv': 'TV',
      'curtain': '커튼',
      'fan': '선풍기',
      'ac': '에어컨',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 이름 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('등록된 기기의 이름을 변경할 수 있습니다.'),
            const SizedBox(height: 16),
            ...(deviceMapping.entries.map((entry) => ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(entry.value),
                  subtitle: Text('ID: ${entry.key}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDeviceInputDialog(entry.key, entry.value);
                  },
                ))),
          ],
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

  void _showRenameDeviceInputDialog(String deviceId, String currentName) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$currentName 이름 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '새로운 이름',
                hintText: '기기 이름을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                _renameDevice(deviceId, newName);
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  void _addDevice(String deviceId, String deviceName) async {
    final success = await DeviceService.addDevice(deviceId, deviceName);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $deviceName 기기가 추가되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 기기 추가에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _renameDevice(String deviceId, String newName) async {
    final success = await DeviceService.updateDeviceName(deviceId, newName);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 기기 이름이 "$newName"으로 변경되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 기기 이름 변경에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class SearchResult {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final SearchAction action;
  final Map<String, dynamic> actionData;

  SearchResult({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.action,
    required this.actionData,
  });
}

enum SearchAction {
  navigateToDevice,
  navigateToFunction,
  showHelp,
}
