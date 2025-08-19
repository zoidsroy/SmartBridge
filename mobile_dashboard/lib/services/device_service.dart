import 'package:firebase_database/firebase_database.dart';
import 'auth_service.dart';

class DeviceService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final AuthService _authService = AuthService();

  /// 기기 이름을 Firebase에 저장
  static Future<bool> updateDeviceName(String deviceId, String newName) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return false;
      }

      print('💾 기기 이름 업데이트: $deviceId → $newName');

      // 사용자별 컬렉션 존재 여부 확인 및 생성
      await _ensureUserCollectionsExist(uid);

      // Firebase에 기기 이름 저장
      await _database.child('users/$uid/device_names/$deviceId').set({
        'name': newName,
        'updated_at': ServerValue.timestamp,
      });

      print('✅ 기기 이름 업데이트 완료: users/$uid/device_names/$deviceId');
      return true;
    } catch (e) {
      print('❌ 기기 이름 업데이트 실패: $e');
      return false;
    }
  }

  /// 기기 이름을 Firebase에서 가져오기
  static Future<String?> getDeviceName(String deviceId) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return null;
      }

      final snapshot =
          await _database.child('users/$uid/device_names/$deviceId').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data['name'] as String?;
      }

      return null;
    } catch (e) {
      print('❌ 기기 이름 조회 실패: $e');
      return null;
    }
  }

  /// 모든 기기 이름을 Firebase에서 가져오기
  static Future<Map<String, String>> getAllDeviceNames() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return {};
      }

      final snapshot = await _database.child('users/$uid/device_names').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final deviceNames = <String, String>{};

        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            deviceNames[key.toString()] = value['name']?.toString() ?? '';
          }
        });

        return deviceNames;
      }

      return {};
    } catch (e) {
      print('❌ 모든 기기 이름 조회 실패: $e');
      return {};
    }
  }

  /// 기본 기기 이름 매핑
  static Map<String, String> getDefaultDeviceNames() {
    return {
      'light': '전등',
      'tv': 'TV',
      'curtain': '커튼',
      'fan': '선풍기',
      'ac': '에어컨',

    };
  }

  /// 기기 추가 (새로운 기기를 사용자 계정에 추가)
  static Future<bool> addDevice(String deviceId, String deviceName) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return false;
      }

      print('➕ 기기 추가: $deviceId ($deviceName)');

      // 사용자별 컬렉션 존재 여부 확인 및 생성
      await _ensureUserCollectionsExist(uid);

      // Firebase에 기기 추가
      await _database.child('users/$uid/devices/$deviceId').set({
        'name': deviceName,
        'added_at': ServerValue.timestamp,
        'is_active': true,
      });

      // 기기 이름도 함께 저장
      await updateDeviceName(deviceId, deviceName);

      print('✅ 기기 추가 완료: users/$uid/devices/$deviceId');
      return true;
    } catch (e) {
      print('❌ 기기 추가 실패: $e');
      return false;
    }
  }

  /// 사용자의 활성 기기 목록 가져오기
  static Future<Map<String, String>> getActiveDevices() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return getDefaultDeviceNames();
      }

      final snapshot = await _database.child('users/$uid/devices').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final activeDevices = <String, String>{};

        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic> &&
              (value['is_active'] == null || value['is_active'] == true)) {
            activeDevices[key.toString()] = value['name']?.toString() ?? '';
          }
        });

        return activeDevices;
      }

      // 기본 기기 목록 반환
      return getDefaultDeviceNames();
    } catch (e) {
      print('❌ 활성 기기 목록 조회 실패: $e');
      return getDefaultDeviceNames();
    }
  }

  /// 초기 기기 등록 (모든 기본 기기를 한 번에 등록)
  static Future<bool> initializeDefaultDevices() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보가 없습니다.');
        return false;
      }

      print('🚀 초기 기기 등록 시작...');

      final defaultNames = getDefaultDeviceNames();
      int successCount = 0;

      for (final entry in defaultNames.entries) {
        final deviceId = entry.key;
        final deviceName = entry.value;

        try {
          // 기기 이름 저장
          await _database.child('users/$uid/device_names/$deviceId').set({
            'name': deviceName,
            'created_at': ServerValue.timestamp,
          });

          // 기기 목록에 추가
          await _database.child('users/$uid/devices/$deviceId').set({
            'name': deviceName,
            'type': deviceId,
            'created_at': ServerValue.timestamp,
            'is_active': true,
          });

          print('✅ $deviceName ($deviceId) 등록 완료');
          successCount++;
        } catch (e) {
          print('⚠️ $deviceName ($deviceId) 등록 실패: $e');
        }
      }

      print('🎉 초기 기기 등록 완료: $successCount/${defaultNames.length}개 성공');
      return successCount > 0;
    } catch (e) {
      print('❌ 초기 기기 등록 실패: $e');
      return false;
    }
  }

  /// 사용자별 컬렉션 존재 확인 및 생성
  static Future<void> _ensureUserCollectionsExist(String uid) async {
    try {
      print('🔧 DeviceService: 사용자별 컬렉션 확인 및 생성: $uid');

      // device_names 컬렉션 확인
      final deviceNamesSnapshot =
          await _database.child('users/$uid/device_names').once();

      if (!deviceNamesSnapshot.snapshot.exists) {
        print('📁 device_names 컬렉션 생성 중...');
        await _database
            .child('users/$uid/device_names')
            .set({'created_at': DateTime.now().toIso8601String()});
        print('✅ device_names 컬렉션 생성 완료');
      } else {
        print('✅ device_names 컬렉션이 이미 존재합니다');
      }

      // devices 컬렉션 확인
      final devicesSnapshot =
          await _database.child('users/$uid/devices').once();

      if (!devicesSnapshot.snapshot.exists) {
        print('📁 devices 컬렉션 생성 중...');
        await _database
            .child('users/$uid/devices')
            .set({'created_at': DateTime.now().toIso8601String()});
        print('✅ devices 컬렉션 생성 완료');
      } else {
        print('✅ devices 컬렉션이 이미 존재합니다');
      }
    } catch (e) {
      print('❌ DeviceService: 사용자별 컬렉션 생성 오류: $e');
    }
  }
}
