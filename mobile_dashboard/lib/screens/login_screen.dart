import 'package:flutter/material.dart';
import 'package:iot_smarthome/services/auth_service.dart';
import 'package:iot_smarthome/screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUserIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _keepLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLoginInfo();
  }

  @override
  void dispose() {
    _emailOrUserIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username') ?? '';
    final keepLoggedIn = prefs.getBool('keep_logged_in') ?? false;
    
    setState(() {
      _emailOrUserIdController.text = savedUsername;
      _keepLoggedIn = keepLoggedIn;
    });
  }

  Future<void> _saveLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (_keepLoggedIn) {
      await prefs.setString('saved_username', _emailOrUserIdController.text.trim());
      await prefs.setBool('keep_logged_in', true);
    } else {
      await prefs.remove('saved_username');
      await prefs.setBool('keep_logged_in', false);
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = await _authService.signInWithEmailOrUserId(
        _emailOrUserIdController.text.trim(),
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null && mounted) {
        // 로그인 정보 저장
        await _saveLoginInfo();
        Navigator.of(context).pushReplacementNamed('/main_screen');
      }
    }
  }

  void _goToFindAccount() {
    Navigator.pushNamed(context, '/find_account');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // 로고 또는 앱 제목
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2196F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Smart Bridge',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'IoT 스마트홈 제어 시스템',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // 아이디/이메일 입력 필드
                TextFormField(
                  controller: _emailOrUserIdController,
                  decoration: InputDecoration(
                    labelText: '아이디 또는 이메일',
                    prefixIcon: const Icon(Icons.account_circle_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    helperText: '아이디 또는 이메일 주소를 입력하세요',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '아이디 또는 이메일을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // 비밀번호 입력 필드
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요.';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 6자 이상이어야 합니다.';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 10),
                
                // 계정/비밀번호 찾기
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _goToFindAccount,
                    child: const Text('계정/비밀번호를 잊으셨나요?'),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // 로그인 상태 유지 체크박스
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: _keepLoggedIn,
                          onChanged: (bool? value) {
                            setState(() {
                              _keepLoggedIn = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF2196F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '로그인 상태 유지',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 로그인 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(height: 20),
                
                // 구분선
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[400])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '또는',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[400])),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 회원가입 버튼
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 