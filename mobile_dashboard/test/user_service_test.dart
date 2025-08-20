import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smarthome/services/user_service.dart';
import 'package:iot_smarthome/models/user_model.dart';

void main() {
  group('UserService Tests', () {
    late UserService userService;

    setUp(() {
      userService = UserService();
    });

    test('UserService 인스턴스 생성 테스트', () {
      expect(userService, isNotNull);
      expect(userService, isA<UserService>());
    });

    test('사용자 아이디 중복 확인 메서드 존재 테스트', () {
      expect(userService.isUserIdAvailable, isA<Function>());
    });

    test('전화번호 중복 확인 메서드 존재 테스트', () {
      expect(userService.isPhoneNumberAvailable, isA<Function>());
    });

    test('사용자 정보 저장 메서드 존재 테스트', () {
      expect(userService.saveUser, isA<Function>());
    });

    test('UID로 사용자 정보 가져오기 메서드 존재 테스트', () {
      expect(userService.getUserByUid, isA<Function>());
    });

    test('이름과 전화번호로 아이디 찾기 메서드 존재 테스트', () {
      expect(userService.findUserIdByNameAndPhone, isA<Function>());
    });

    test('아이디와 전화번호로 이메일 찾기 메서드 존재 테스트', () {
      expect(userService.getEmailByUserIdAndPhone, isA<Function>());
    });
  });
}
