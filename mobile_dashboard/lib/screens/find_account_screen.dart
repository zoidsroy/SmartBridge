import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iot_smarthome/services/user_service.dart';
import 'package:iot_smarthome/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({super.key});

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // 아이디 찾기 관련
  final _findIdFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoadingFindId = false;
  String? _foundUserId;

  // 비밀번호 찾기 관련
  final _findPasswordFormKey = GlobalKey<FormState>();
  final _userIdForPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneForPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoadingFindPassword = false;
  bool _isEmailVerification = true; // true: 이메일, false: 전화번호
  bool _isCodeSent = false;
  bool _isCodeVerified = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _verificationId;
  String? _generatedCode;
  int _resendCooldown = 0;

  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _userIdForPasswordController.dispose();
    _emailController.dispose();
    _phoneForPasswordController.dispose();
    _verificationCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 아이디 찾기
  Future<void> _findUserId() async {
    if (!_findIdFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingFindId = true;
      _foundUserId = null;
    });

    try {
      final userId = await _userService.findUserIdByNameAndPhone(
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );

      setState(() {
        _foundUserId = userId;
      });

      if (userId != null) {
        _showFoundUserIdDialog(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일치하는 계정을 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingFindId = false;
      });
    }
  }

  void _showFoundUserIdDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아이디 찾기 성공'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text('회원님의 아이디는 다음과 같습니다:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: userId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('아이디가 클립보드에 복사되었습니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: '복사',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 찾기 화면도 닫기
            },
            child: const Text('로그인하러 가기'),
          ),
        ],
      ),
    );
  }

  // 이메일로 비밀번호 재설정 링크 발송
  Future<void> _sendEmailPasswordReset() async {
    if (_userIdForPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingFindPassword = true;
    });

    try {
      // 아이디와 이메일이 일치하는지 먼저 확인
      String userId = _userIdForPasswordController.text.trim();
      String inputEmail = _emailController.text.trim();
      String? registeredEmail = await _userService.getEmailByUserId(userId);

      if (registeredEmail == null || registeredEmail != inputEmail) {
        throw Exception('아이디와 이메일이 일치하지 않습니다.');
      }

      // Firebase Auth를 통한 비밀번호 재설정 이메일 발송
      await FirebaseAuth.instance.sendPasswordResetEmail(email: inputEmail);

      _showPasswordResetSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('본인 확인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingFindPassword = false;
      });
    }
  }

  // 전화번호 인증 코드 발송 (Firebase Phone Auth)
  Future<void> _sendPhoneVerification() async {
    if (_userIdForPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_phoneForPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingFindPassword = true;
    });

    try {
      // 아이디와 전화번호가 일치하는지 먼저 확인
      String userId = _userIdForPasswordController.text.trim();
      String phoneNumber = _phoneForPasswordController.text.trim();
      String? email = await _userService.getEmailByUserIdAndPhone(userId, phoneNumber);

      if (email == null) {
        throw Exception('아이디와 전화번호가 일치하지 않습니다.');
      }

      // 전화번호 형식 변환 (01012345678 -> +821012345678)
      String formattedPhone = '+82${phoneNumber.substring(1)}';
      
      print('📱 SMS 발송 시도: $formattedPhone');

      // Firebase Phone Auth 사용
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 자동 인증 완료 (일부 Android에서만 작동)
          print('📱 자동 인증 완료');
          setState(() {
            _isCodeVerified = true;
            _isLoadingFindPassword = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('자동 인증이 완료되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          print('📱 SMS 인증 실패: ${e.code} - ${e.message}');
          
          setState(() {
            _isLoadingFindPassword = false;
          });
          
          String errorMessage = '';
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = '잘못된 전화번호 형식입니다.';
              break;
            case 'too-many-requests':
              errorMessage = '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
              break;
            case 'operation-not-allowed':
              errorMessage = '전화번호 인증이 비활성화되어 있습니다.';
              break;
            default:
              errorMessage = 'SMS 발송에 실패했습니다: ${e.message}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print('📱 SMS 발송 완료: $verificationId');
          
          setState(() {
            _verificationId = verificationId;
            _isCodeSent = true;
            _resendCooldown = 180; // 3분
            _isLoadingFindPassword = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('본인 확인 완료!\nSMS 인증번호가 $phoneNumber로 발송되었습니다.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          _startCooldownTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('📱 SMS 자동 인증 시간 초과: $verificationId');
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('📱 SMS 발송 예외: $e');
      
      setState(() {
        _isLoadingFindPassword = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('본인 확인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startCooldownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCooldown > 0 && mounted) {
        setState(() {
          _resendCooldown--;
        });
        _startCooldownTimer();
      }
    });
  }

  // 인증번호 확인 (SMS만 해당)
  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증번호를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingFindPassword = true;
    });

    try {
      if (_verificationId != null) {
        // Firebase Phone Auth 인증번호 확인
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _verificationCodeController.text.trim(),
        );
        
        print('📱 SMS 인증번호 확인 시도: ${_verificationCodeController.text.trim()}');
        
        // 임시로 인증하여 유효성 확인
        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        
        // 임시 인증 성공 후 즉시 로그아웃
        await FirebaseAuth.instance.signOut();
        
        print('📱 SMS 인증 성공');
        
        setState(() {
          _isCodeVerified = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS 인증이 완료되었습니다. 비밀번호 재설정 이메일을 발송합니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('인증 ID가 없습니다. 다시 시도해주세요.');
      }
    } on FirebaseAuthException catch (e) {
      print('📱 SMS 인증 실패: ${e.code} - ${e.message}');
      
      String errorMessage = '';
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = '인증번호가 올바르지 않습니다.';
          break;
        case 'session-expired':
          errorMessage = '인증 시간이 만료되었습니다. 다시 인증번호를 요청해주세요.';
          break;
        default:
          errorMessage = '인증에 실패했습니다: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('📱 SMS 인증 예외: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인증 확인에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingFindPassword = false;
      });
    }
  }

  // 비밀번호 재설정
  Future<void> _resetPassword() async {
    if (!_findPasswordFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingFindPassword = true;
    });

    try {
      String userId = _userIdForPasswordController.text.trim();
      String? email;

      if (_isEmailVerification) {
        // 이메일 인증의 경우 - 아이디와 이메일이 일치하는지 확인
        String inputEmail = _emailController.text.trim();
        email = await _userService.getEmailByUserId(userId);
        
        if (email == null || email != inputEmail) {
          throw Exception('아이디와 이메일이 일치하지 않습니다.');
        }
      } else {
        // 전화번호 인증의 경우 - 아이디와 전화번호로 이메일 찾기
        String phoneNumber = _phoneForPasswordController.text.trim();
        email = await _userService.getEmailByUserIdAndPhone(userId, phoneNumber);
        
        if (email == null) {
          throw Exception('아이디와 전화번호가 일치하지 않습니다.');
        }
      }

      // Firebase Auth를 통한 비밀번호 재설정 이메일 발송
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showPasswordResetSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('비밀번호 재설정에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingFindPassword = false;
      });
    }
  }

  void _showPasswordResetSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 재설정'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.email_outlined,
              color: Colors.blue,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '비밀번호 재설정 링크가 이메일로 발송되었습니다.\n이메일을 확인하여 비밀번호를 변경해주세요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 찾기 화면도 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('계정 찾기'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2196F3),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2196F3),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2196F3),
          tabs: const [
            Tab(text: '아이디 찾기'),
            Tab(text: '비밀번호 찾기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindIdTab(),
          _buildFindPasswordTab(),
        ],
      ),
    );
  }

  Widget _buildFindIdTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _findIdFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '가입 시 등록한 이름과 전화번호를 입력하면\n아이디를 찾을 수 있습니다.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '이름',
                prefixIcon: const Icon(Icons.person_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '이름을 입력해주세요.';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '전화번호',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: '예: 01012345678',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '전화번호를 입력해주세요.';
                }
                if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(value.replaceAll('-', ''))) {
                  return '올바른 휴대폰 번호를 입력해주세요.';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: _isLoadingFindId ? null : _findUserId,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoadingFindId
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '아이디 찾기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _findPasswordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '아이디와 이메일 또는 전화번호로 본인 확인 후\n비밀번호 재설정 이메일을 받을 수 있습니다.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 인증 방법 선택
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEmailVerification = true;
                          _isCodeSent = false;
                          _isCodeVerified = false;
                          _verificationCodeController.clear();
                          _resendCooldown = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isEmailVerification ? const Color(0xFF2196F3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '이메일 인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isEmailVerification ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEmailVerification = false;
                          _isCodeSent = false;
                          _isCodeVerified = false;
                          _verificationCodeController.clear();
                          _resendCooldown = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isEmailVerification ? const Color(0xFF2196F3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SMS 인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isEmailVerification ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 아이디 입력 (공통)
            TextFormField(
              controller: _userIdForPasswordController,
              decoration: InputDecoration(
                labelText: '아이디',
                prefixIcon: const Icon(Icons.person_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '아이디를 입력해주세요.';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // 이메일/전화번호 입력
            if (_isEmailVerification)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return '올바른 이메일 형식을 입력해주세요.';
                  }
                  return null;
                },
              )
            else
              TextFormField(
                controller: _phoneForPasswordController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '예: 01012345678',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '전화번호를 입력해주세요.';
                  }
                  if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(value.replaceAll('-', ''))) {
                    return '올바른 휴대폰 번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
            
            const SizedBox(height: 20),
            
            // 인증 버튼
            if (_isEmailVerification)
              // 이메일 인증 - 바로 비밀번호 재설정 이메일 발송
              ElevatedButton(
                onPressed: _isLoadingFindPassword ? null : _sendEmailPasswordReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingFindPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '본인 확인 후 비밀번호 재설정 이메일 발송',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )
            else
              // SMS 인증 - 인증번호 발송 후 확인 과정 필요
              if (!_isCodeSent)
                ElevatedButton(
                  onPressed: _isLoadingFindPassword ? null : _sendPhoneVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingFindPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '본인 확인 후 SMS 인증번호 발송',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            
            // 인증번호 입력 및 확인 (SMS 인증만 해당)
            if (!_isEmailVerification && _isCodeSent && !_isCodeVerified) ...[
              TextFormField(
                controller: _verificationCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '인증번호',
                  prefixIcon: const Icon(Icons.security_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '6자리 인증번호를 입력하세요',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '인증번호를 입력해주세요.';
                  }
                  if (value.length != 6) {
                    return '6자리 인증번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoadingFindPassword ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('인증번호 확인'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _resendCooldown > 0 ? null : _sendPhoneVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_resendCooldown > 0 
                        ? '${(_resendCooldown / 60).floor()}:${(_resendCooldown % 60).toString().padLeft(2, '0')}'
                        : '재발송'),
                  ),
                ],
              ),
            ],
            
            // 비밀번호 재설정 (SMS 인증 완료 후)
            if (!_isEmailVerification && _isCodeVerified) ...[
              const SizedBox(height: 30),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '인증이 완료되었습니다.\n비밀번호 재설정 이메일을 발송합니다.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: _isLoadingFindPassword ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingFindPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '비밀번호 재설정 이메일 발송',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 