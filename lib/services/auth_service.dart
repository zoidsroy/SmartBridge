import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iot_smarthome/models/user_model.dart';
import 'package:iot_smarthome/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 회원가입 (상세 정보 포함)
  Future<User?> signUpWithUserInfo({
    required String userId,
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
    required String country,
    required String city,
    required String phoneNumber,
  }) async {
    try {
      // 아이디 중복 확인
      bool isUserIdAvailable = await _userService.isUserIdAvailable(userId);
      if (!isUserIdAvailable) {
        Fluttertoast.showToast(
          msg: "이미 사용 중인 아이디입니다.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return null;
      }

      // 전화번호 중복 확인
      bool isPhoneAvailable = await _userService.isPhoneNumberAvailable(phoneNumber);
      if (!isPhoneAvailable) {
        Fluttertoast.showToast(
          msg: "이미 사용 중인 전화번호입니다.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return null;
      }

      // Firebase Authentication으로 계정 생성
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 사용자 정보를 Firestore에 저장
        UserModel userModel = UserModel(
          uid: credential.user!.uid,
          userId: userId,
          email: email,
          name: name,
          age: age,
          gender: gender,
          country: country,
          city: city,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
        );

        bool saved = await _userService.saveUser(userModel);
        if (saved) {
          // 이메일 인증 발송
          await credential.user?.sendEmailVerification();
          
          Fluttertoast.showToast(
            msg: "회원가입이 완료되었습니다. 이메일 인증을 확인해주세요.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          
          return credential.user;
        } else {
          // Firestore 저장 실패 시 Authentication 계정도 삭제
          await credential.user?.delete();
          Fluttertoast.showToast(
            msg: "회원가입 중 오류가 발생했습니다. 다시 시도해주세요.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return null;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "회원가입 중 오류가 발생했습니다: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    }
  }

  // 이메일 또는 아이디로 로그인
  Future<User?> signInWithEmailOrUserId(String emailOrUserId, String password) async {
    try {
      String email;
      
      // 이메일 형식인지 확인
      if (emailOrUserId.contains('@')) {
        email = emailOrUserId;
      } else {
        // 아이디로 이메일 찾기
        String? foundEmail = await _userService.getEmailByUserId(emailOrUserId);
        
        if (foundEmail == null) {
          Fluttertoast.showToast(
            msg: "존재하지 않는 아이디입니다.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return null;
        }
        email = foundEmail;
      }

      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      Fluttertoast.showToast(
        msg: "로그인 성공!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
      return credential.user;
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "로그인 중 오류가 발생했습니다: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
    
    // 로그인 상태 유지 정보 클리어
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keep_logged_in', false);
    await prefs.remove('saved_username');
    
    Fluttertoast.showToast(
      msg: "로그아웃되었습니다.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey,
      textColor: Colors.white,
    );
  }

  // 비밀번호 재설정 이메일 발송 (이메일/아이디/전화번호로 찾기)
  Future<void> sendPasswordResetByEmailOrUserIdOrPhone(String identifier) async {
    try {
      String? email;

      // 이메일 형식인지 확인
      if (identifier.contains('@')) {
        email = identifier;
      } else if (identifier.startsWith('01') && identifier.length >= 10) {
        // 전화번호로 이메일 찾기 (한국 휴대폰 번호 패턴)
        email = await _userService.getEmailByPhoneNumber(identifier);
        if (email == null) {
          Fluttertoast.showToast(
            msg: "해당 전화번호로 등록된 계정이 없습니다.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return;
        }
      } else {
        // 아이디로 이메일 찾기
        email = await _userService.getEmailByUserId(identifier);
        if (email == null) {
          Fluttertoast.showToast(
            msg: "해당 아이디로 등록된 계정이 없습니다.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return;
        }
      }

      await _auth.sendPasswordResetEmail(email: email);
      Fluttertoast.showToast(
        msg: "비밀번호 재설정 이메일을 $email 로 발송했습니다.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "비밀번호 재설정 요청 중 오류가 발생했습니다: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // 현재 사용자 정보 가져오기
  Future<UserModel?> getCurrentUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return await _userService.getUserByUid(user.uid);
    }
    return null;
  }

  // 자동 로그인 여부 확인
  Future<bool> shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final keepLoggedIn = prefs.getBool('keep_logged_in') ?? false;
    final currentUser = _auth.currentUser;
    
    return keepLoggedIn && currentUser != null;
  }

  // Firebase Auth 에러 메시지를 한국어로 변환
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return '존재하지 않는 사용자입니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
      case 'invalid-email':
        return '유효하지 않은 이메일 주소입니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      default:
        return '인증 오류가 발생했습니다: $errorCode';
    }
  }
} 