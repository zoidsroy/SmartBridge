import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iot_smarthome/services/auth_service.dart';
import 'package:iot_smarthome/screens/login_screen.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  void _showToast(String message) {
    Fluttertoast.showToast(msg: message);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // 🔙 뒤로가기 버튼 (필요할 때만 표시)
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),

          // 🏷️ 'AIOT 스마트홈' 타이틀 버튼
          TextButton(
            onPressed: () {
              // PageView index = 1로 이동 (HOME)
              DefaultTabController.of(context)?.animateTo(1);
              Navigator.pushReplacementNamed(context, '/main_screen');
            },
            child: const Text(
              'AIOT 스마트홈',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),

          // ⚙️ 오른쪽 버튼들
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            icon: const Icon(Icons.search, color: Colors.blue),
            tooltip: '검색',
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/recommendation');
            },
            icon: const Icon(Icons.analytics, color: Colors.green),
            tooltip: '추천',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/user_profile');
              } else if (value == 'logout') {
                _showLogoutDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('회원정보'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.account_circle, color: Colors.blue),
            tooltip: '계정',
          ),
        ],
      ),
    );
  }
}
