import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'header.dart';

class DeviceListScreen extends StatefulWidget {
  DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final List<String> devices = ['전등', '선풍기', '커튼', '에어컨', 'TV'];
  final List<String> devicesEng = ['light', 'fan', 'curtain', 'ac', 'tv'];
  final List<String> imagePaths = [
    'assets/icons/light.png',
    'assets/icons/fan.png',
    'assets/icons/curtain.png',
    'assets/icons/ac.png',
    'assets/icons/tv.png',
  ];

  @override
  void initState() {
    super.initState();
    // 웹에서 이미지 미리 캐싱
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (String imagePath in imagePaths) {
        precacheImage(AssetImage(imagePath), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance;

    return SafeArea(
      child: Column(
        children: [
          const Header(),
          const Padding(
            padding: EdgeInsets.only(right: 16.0, top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.circle, color: Colors.green, size: 12),
                SizedBox(width: 4),
                Text('연결됨'),
                SizedBox(width: 16),
                Icon(Icons.circle, color: Colors.red, size: 12),
                SizedBox(width: 4),
                Text('사용할 수 없음'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: db.ref().onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('연결된 장치 없음'));
                }

                final data = snapshot.data!.snapshot.value as Map;
                final gestureMap = (data['control_gesture'] ?? {}) as Map;
                final statusMap = (data['status'] ?? {}) as Map;

                // 모든 기기를 연결된 상태로 표시
                final connectedSet = devicesEng.toSet();

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final deviceKey = devicesEng[index];
                    final isConnected = connectedSet.contains(deviceKey);

                    final powerStatus = statusMap[deviceKey]?['power'] ?? 'off';
                    final isOn = powerStatus == 'on';

                    return GestureDetector(
                      onTap: () {
                        print('🔍 기기 클릭됨: ${devices[index]} ($deviceKey)');
                        print('🔗 연결 상태: $isConnected');

                        if (!isConnected) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('사용할 수 없는 상태입니다')),
                          );
                          return;
                        }

                        print('📱 네비게이션 시작: /device_detail_screen');
                        try {
                          Navigator.pushNamed(
                            context,
                            '/device_detail_screen',
                            arguments: {
                              'label': devices[index],
                              'key': deviceKey,
                              'iconPath': imagePaths[index],
                            },
                          );
                          print('✅ 네비게이션 성공');
                        } catch (e) {
                          print('❌ 네비게이션 오류: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('오류: ${e.toString()}')),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            // 중앙 내용
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    imagePaths[index],
                                    width: 60,
                                    height: 60,
                                    errorBuilder: (context, error, stackTrace) {
                                      print(
                                          '이미지 로딩 오류: ${imagePaths[index]} - $error');
                                      return const Icon(
                                        Icons.error,
                                        size: 60,
                                        color: Colors.red,
                                      );
                                    },
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    devices[index],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 연결 상태 표시 (오른쪽 상단)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.circle,
                                color: isConnected ? Colors.green : Colors.red,
                                size: 12,
                              ),
                            ),
                            // 전원 상태 표시 (왼쪽 상단)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.power_settings_new,
                                    size: 18,
                                    color: isOn ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOn ? 'on' : 'off',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOn ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
