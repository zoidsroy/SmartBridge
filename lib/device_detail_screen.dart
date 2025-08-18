import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'header.dart';
import 'services/remote_control_service.dart';
import 'services/auth_service.dart';
import 'screens/remote_control_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String label;
  final String keyName;
  final String iconPath;

  const DeviceDetailScreen({
    required this.label,
    required this.keyName,
    required this.iconPath,
    super.key,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/gesture_customization',
                        arguments: {
                          'keyName': widget.keyName,
                          'deviceName': widget.label,
                        },
                      );
                    },
                    icon: const Icon(Icons.gesture, size: 16),
                    label: const Text('제스쳐 설정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('status/${widget.keyName}')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  final status = snapshot.data!.snapshot.value as Map;
                  final powerStatus = status['power'] ?? 'off';
                  final isOnline = status['online'] ?? false;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOnline ? Colors.green[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: isOnline ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? '온라인' : '오프라인',
                          style: TextStyle(
                            color:
                                isOnline ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.power_settings_new,
                          color:
                              powerStatus == 'on' ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          powerStatus == 'on' ? '켜짐' : '꺼짐',
                          style: TextStyle(
                            color: powerStatus == 'on'
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildGestureListPage(),
                  _buildRemoteControlPage(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureListPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '제스처 목록',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref(
                      'gestureMapping/${FirebaseAuth.instance.currentUser?.uid ?? 'unknown'}/${widget.keyName}')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  final data = snapshot.data!.snapshot.value as Map;
                  final entries = data.entries.toList();

                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('설정된 제스처가 없습니다.\n제스처 설정 버튼을 눌러 제스처를 추가해보세요.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final gestureKey = entries[index].key.toString();
                      final label =
                          (entries[index].value as Map)['label']?.toString() ??
                              '-';

                      return ListTile(
                        title: Text(label),
                        trailing: Text(gestureKey),
                        dense: true,
                      );
                    },
                  );
                }

                return const Center(
                  child: Text('제스처 목록을 불러오는 중...'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteControlPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('리모컨',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RemoteControlScreen(
                        deviceId: widget.keyName,
                        deviceName: widget.label,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('전체 보기', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: RemoteControlService.getIRCodes(widget.keyName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phonelink_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('리모컨 데이터가 없습니다.'),
                        SizedBox(height: 8),
                        Text('전체 리모컨 화면에서 더 많은 기능을 확인해보세요.'),
                      ],
                    ),
                  );
                }

                final irCodes = snapshot.data!;
                final commands = irCodes.entries.take(6).toList();

                return ListView.builder(
                  itemCount: commands.length,
                  itemBuilder: (context, index) {
                    final command = commands[index].key;
                    final irData = commands[index].value;
                    return _buildIRRemoteButton(command, irData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIRRemoteButton(String command, Map<String, dynamic> irData) {
    final label = RemoteControlService.getCommandLabel(command);
    final icon = RemoteControlService.getCommandIcon(command);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: Text(icon, style: const TextStyle(fontSize: 20)),
          title: Text(label),
          trailing: const Icon(Icons.send),
          onTap: () async {
            try {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              final success = await RemoteControlService.sendIRCode(
                deviceId: widget.keyName,
                command: command,
                irData: irData,
              );

              if (mounted) Navigator.of(context).pop();

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label 전송됨'),
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
              if (mounted) Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? Colors.black : Colors.grey,
      ),
    );
  }
}
