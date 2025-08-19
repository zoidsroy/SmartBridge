import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iot_smarthome/screens/login_screen.dart';
import 'package:iot_smarthome/services/auth_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isCheckingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final shouldAutoLogin = await _authService.shouldAutoLogin();
    
    if (mounted) {
      setState(() {
        _isCheckingAutoLogin = false;
      });

      if (shouldAutoLogin) {
        Navigator.of(context).pushReplacementNamed('/main_screen');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
              SizedBox(height: 20),
              Text(
                'Smart Bridge',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '자동 로그인 확인 중...',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 로딩 중일 때
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF2196F3),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Smart Bridge',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '로딩 중...',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 로그인 상태에 따른 화면 라우팅
        if (snapshot.hasData && snapshot.data != null) {
          // 로그인된 상태 - 메인 화면으로 (3개 탭이 있는 화면)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/main_screen');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          // 로그인되지 않은 상태 - 로그인 화면으로
          return const LoginScreen();
        }
      },
    );
  }
} 