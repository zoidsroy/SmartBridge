import 'package:flutter/material.dart';
import '../services/remote_control_service.dart';

class RemoteControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const RemoteControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  Map<String, Map<String, dynamic>> _irCodes = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIRCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIRCodes() async {
    try {
      final irCodes = await RemoteControlService.getIRCodes(widget.deviceId);
      if (mounted) {
        setState(() {
          _irCodes = irCodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('IR 코드 로딩 실패: $e')),
        );
      }
    }
  }

  Future<void> _sendCommand(String command, Map<String, dynamic> irData) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await RemoteControlService.sendIRCode(
        deviceId: widget.deviceId,
        command: command,
        irData: irData,
      );

      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // 로그 기록 부분 제거 - 단순히 IR신호만 전송
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${RemoteControlService.getCommandLabel(command)} 전송됨',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('명령 전송 실패'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> _getFilteredCommands() {
    return RemoteControlService.searchCommands(_irCodes, _searchQuery);
  }

  Widget _buildRemoteButton(String command, Map<String, dynamic> irData) {
    final label = RemoteControlService.getCommandLabel(command);
    final icon = RemoteControlService.getCommandIcon(command);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _sendCommand(command, irData),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deviceName} 리모컨'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadIRCodes,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '기능 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // 로딩 상태
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          
          // IR 코드가 없는 경우
          else if (_irCodes.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phonelink_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.deviceName}의 IR 코드가 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Firebase에서 ir_codes/${widget.deviceId} 경로를 확인하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          
          // 리모컨 버튼들
          else
            Expanded(
              child: _buildRemoteGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteGrid() {
    final filteredCommands = _getFilteredCommands();
    
    if (filteredCommands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: filteredCommands.length,
        itemBuilder: (context, index) {
          final entry = filteredCommands[index];
          return _buildRemoteButton(entry.key, entry.value);
        },
      ),
    );
  }
} 