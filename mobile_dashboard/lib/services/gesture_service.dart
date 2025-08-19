import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backend_api_service.dart';

class GestureService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 ID 가져오기
  static String? get _currentUserId => _auth.currentUser?.uid;

  // 💾 모드 진입 제스처 저장 (사용자별)
  static Future<bool> saveModeEntryGesture(
      String deviceId, String? gestureKey) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('💾 모드 진입 제스처 저장: $deviceId (사용자: $uid)');
      print('📝 저장할 제스처: $gestureKey');
      print('🗄️ 저장 경로: users/$uid/mode_gesture/$deviceId');

      // 사용자별 컬렉션 존재 여부 확인 및 생성
      await _ensureUserCollectionsExist(uid);

      if (gestureKey == null || gestureKey.isEmpty) {
        // 제스처가 없으면 해당 제스처 문서를 찾아서 삭제
        print('🔍 기존 제스처 매핑 찾는 중...');
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('mode_gesture')
            .where('device', isEqualTo: deviceId)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
          print('✅ 기존 제스처 매핑 삭제: ${doc.id}');
        }
        print('✅ 모드 진입 제스처 삭제 완료');
      } else {
        // 기존 매핑이 있으면 먼저 삭제
        print('🔍 기존 제스처 매핑 찾아서 삭제 중...');
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('mode_gesture')
            .where('device', isEqualTo: deviceId)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
          print('✅ 기존 제스처 매핑 삭제: ${doc.id}');
        }

        // 새로운 구조로 저장: gestureKey → {device: "deviceId"}
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('mode_gesture')
            .doc(gestureKey)
            .set({
          'device': deviceId,
        });
        print('✅ 모드 진입 제스처 저장 완료: $gestureKey → {device: $deviceId}');
      }

      return true;
    } catch (e) {
      print('❌ 모드 진입 제스처 저장 오류: $e');
      return false;
    }
  }

  // 🗑️ 모드 진입 제스처 삭제 (사용자별)
  static Future<bool> deleteModeEntryGesture(String deviceId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('🗑️ 모드 진입 제스처 삭제 시작: $deviceId (사용자: $uid)');

      // 새로운 구조에 맞춰 해당 device를 가진 문서들을 찾아서 삭제
      print('🔍 삭제할 제스처 매핑 찾는 중...');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('mode_gesture')
          .where('device', isEqualTo: deviceId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        print('✅ 제스처 매핑 삭제: ${doc.id} → {device: $deviceId}');
      }

      print('✅ 모드 진입 제스처 삭제 완료');
      return true;
    } catch (e) {
      print('❌ 모드 진입 제스처 삭제 오류: $e');
      return false;
    }
  }

  // 🎮 실제 Firebase DB에 존재하는 제스처 목록
  static Map<String, Map<String, dynamic>> getAvailableGestures() {
    return {
      'one': {
        'name': '☝️숫자 1',
        'description': '집게손가락으로 1을 표현',
        'icon': '☝️',
      },
      'two': {
        'name': '✌️ 숫자 2',
        'description': '집게손가락과 중지로 V자',
        'icon': '✌️',
      },
      'three': {
        'name': '🤟 숫자 3',
        'description': '집게손가락, 중지, 약지로 3을 표현',
        'icon': '🤟',
      },
      'four': {
        'name': '🖐️ 숫자 4',
        'description': '4개 손가락으로 4를 표현',
        'icon': '🖐️',
      },
      'small_heart': {
        'name': '💖 작은 하트',
        'description': '엄지와 집게손가락으로 하트 모양',
        'icon': '💖',
      },
      'horizontal_V': {
        'name': '↔️ 수평 V자',
        'description': '수평으로 누운 V자 모양',
        'icon': '↔️',
      },
      'vertical_V': {
        'name': '↕️ 수직 V자',
        'description': '수직으로 선 V자 모양',
        'icon': '↕️',
      },
      'ok': {
        'name': '👌 OK 사인',
        'description': '엄지와 집게손가락으로 원 모양',
        'icon': '👌',
      },
      'promise': {
        'name': '🤙 전화 제스처',
        'description': '전화 받을 때 손의 모습 (엄지와 새끼손가락)',
        'icon': '🤙',
      },
      'clockwise': {
        'name': '🔃 시계방향 회전',
        'description': '손가락을 시계방향으로 회전',
        'icon': '🔃',
      },
      'counter_clockwise': {
        'name': '🔄 반시계방향 회전',
        'description': '손가락을 반시계방향으로 회전',
        'icon': '🔄',
      },
      'slide_left': {
        'name': '⬅️ 손바닥 왼쪽 슬라이드',
        'description': '손바닥을 왼쪽으로 슬라이드',
        'icon': '⬅️',
      },
      'slide_right': {
        'name': '➡️ 손바닥 오른쪽 슬라이드',
        'description': '손바닥을 오른쪽으로 슬라이드',
        'icon': '➡️',
      },
      'spider_man': {
        'name': '🕷️ 스파이더맨',
        'description': '중지와 약지를 접고 엄지, 집게, 새끼 펴기',
        'icon': '🕷️',
      },
      'thumbs_up': {
        'name': '👍 좋아요',
        'description': '엄지손가락 위로',
        'icon': '👍',
      },
      'thumbs_down': {
        'name': '👎 싫어요',
        'description': '엄지손가락 아래로',
        'icon': '👎',
      },
      'thumbs_left': {
        'name': '👈 왼쪽 엄지',
        'description': '엄지손가락 왼쪽',
        'icon': '👈',
      },
      'thumbs_right': {
        'name': '👉 오른쪽 엄지',
        'description': '엄지손가락 오른쪽',
        'icon': '👉',
      },
    };
  }

  // 🏠 기기별 사용 가능한 동작 목록 (실제 Firebase 구조 기반)
  static Map<String, List<Map<String, String>>> getDeviceActions() {
    final actions = {
      'light': [
        {'control': 'power', 'label': '전원'},
        {'control': 'brighter', 'label': '밝게'},
        {'control': 'dimmer', 'label': '어둡게'},
        {'control': 'color', 'label': '색상 변경'},
        {'control': '2min', 'label': '2분 타이머'},
        {'control': '10min', 'label': '10분 타이머'},
        {'control': '30min', 'label': '30분 타이머'},
        {'control': '60min', 'label': '60분 타이머'},
      ],
      'projector': [
        {'control': 'power', 'label': '전원'},
        {'control': 'up', 'label': '위'},
        {'control': 'down', 'label': '아래'},
        {'control': 'left', 'label': '왼쪽'},
        {'control': 'right', 'label': '오른쪽'},
        {'control': 'mid', 'label': '선택/확인'},
        {'control': 'menu', 'label': '메뉴'},
        {'control': 'home', 'label': '홈'},
        {'control': 'back', 'label': '뒤로'},
      ],
      'curtain': [
        {'control': 'power', 'label': '전원'},
      ],
      'fan': [
        {'control': 'power', 'label': '전원'},
        {'control': 'mode', 'label': '모드'},
        {'control': 'stronger', 'label': '바람 강하게'},
        {'control': 'weaker', 'label': '바람 약하게'},
        {'control': 'horizontal', 'label': '수평 회전'},
        {'control': 'vertical', 'label': '수직 회전'},
        {'control': 'timer', 'label': '타이머'},
      ],
      'tv': [
        {'control': 'power', 'label': '전원'},
        {'control': 'back', 'label': '이전'},
        {'control': 'home', 'label': '홈'},
        {'control': 'exit', 'label': '나가기'},
        {'control': 'volumeUP', 'label': '볼륨 올리기'},
        {'control': 'volumeDOWN', 'label': '볼륨 내리기'},
        {'control': 'channelUP', 'label': '채널 올리기'},
        {'control': 'channelDOWN', 'label': '채널 내리기'},
        {'control': 'up', 'label': '상'},
        {'control': 'down', 'label': '하'},
        {'control': 'left', 'label': '좌'},
        {'control': 'right', 'label': '우'},
        {'control': 'ok', 'label': '확인'},
      ],
      'ac': [
        {'control': 'power', 'label': '전원'},
        {'control': 'mode', 'label': '모드'},
        {'control': 'tempUP', 'label': '온도 올리기'},
        {'control': 'tempDOWN', 'label': '온도 내리기'},
        {'control': 'windpowerUP', 'label': '바람 강하게'},
        {'control': 'windpowerDOWN', 'label': '바람 약하게'},
        {'control': 'horizontal', 'label': '수평 회전'},
        {'control': 'vertical', 'label': '수직 회전'},
      ],
    };

    // 디버깅을 위한 로그 추가
    print('🏠 getDeviceActions() 호출됨');
    print('📊 지원되는 기기: ${actions.keys.toList()}');

    return actions;
  }

  // 💾 제스처 매핑 저장 (백엔드 API 우선)
  static Future<bool> saveGestureMapping(
      String deviceId, String gestureId, String control, String label) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('💾 제스처 매핑 저장 시작: $deviceId (사용자: $uid)');
      print('📝 제스처: $gestureId, 제어: $control, 라벨: $label');

      // 1. 백엔드 API 호출 (우선) - 백엔드가 자동으로 Firestore와 RTDB에 저장
      try {
        print('🌐 백엔드 API 호출 중...');
        final success = await BackendApiService.registerMapping(
          uid: uid,
          gesture: gestureId,
          control: control,
          mode: deviceId,
        );

        if (success) {
          print('✅ 백엔드 API 호출 성공 - 백엔드가 자동으로 데이터 저장 완료');
          return true;
        } else {
          print('⚠️ 백엔드 API 호출 실패');
          return false;
        }
      } catch (e) {
        print('❌ 백엔드 API 호출 중 오류: $e');
        return false;
      }
    } catch (e) {
      print('❌ 제스처 매핑 저장 오류: $e');
      return false;
    }
  }

  // 🔄 제스처 매핑 업데이트 (백엔드 API 우선)
  static Future<bool> updateGestureMapping(
      String deviceId, String gestureId, String control, String label) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('🔄 제스처 매핑 업데이트: $deviceId (사용자: $uid)');
      print('📝 제스처: $gestureId, 제어: $control, 라벨: $label');

      // 1. 백엔드 API 호출 (우선) - 백엔드가 자동으로 Firestore와 RTDB에 저장
      try {
        print('🌐 백엔드 API 호출 중...');
        final success = await BackendApiService.updateMapping(
          uid: uid,
          mode: deviceId,
          newGesture: gestureId,
          control: control,
        );

        if (success) {
          print('✅ 백엔드 API 호출 성공 - 백엔드가 자동으로 데이터 업데이트 완료');
          return true;
        } else {
          print('⚠️ 백엔드 API 호출 실패');
          return false;
        }
      } catch (e) {
        print('❌ 백엔드 API 호출 중 오류: $e');
        return false;
      }
    } catch (e) {
      print('❌ 제스처 매핑 업데이트 오류: $e');
      return false;
    }
  }

  // 🗑️ 제스처 매핑 삭제 (백엔드에 삭제 API 없음 - 직접 Firebase 삭제)
  static Future<bool> deleteGestureMapping(
      String deviceId, String gestureId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('🗑️ 제스처 매핑 삭제: $deviceId (사용자: $uid)');
      print('📝 제스처: $gestureId');

      // 백엔드에 삭제 API가 없으므로 직접 Firebase에서 삭제

      // 1. Realtime Database에서 삭제 (백엔드 구조: control_gesture/{uid}/{mode}/{gesture})
      try {
        final database = FirebaseDatabase.instance;
        await database
            .ref('control_gesture/$uid/$deviceId/$gestureId')
            .remove();
        print('✅ Realtime Database에서 삭제 완료');
      } catch (e) {
        print('⚠️ Realtime Database 삭제 실패: $e');
      }

      // 2. Firestore에서 삭제 (백엔드 구조: users/{uid}/control_gesture/{mode}_{control})
      try {
        // control 이름을 먼저 찾아야 함
        final rtdbSnapshot = await FirebaseDatabase.instance
            .ref('control_gesture/$uid/$deviceId/$gestureId')
            .once();

        if (rtdbSnapshot.snapshot.exists) {
          final data = rtdbSnapshot.snapshot.value as Map<dynamic, dynamic>?;
          final control = data?['control'] as String?;

          if (control != null) {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('control_gesture')
                .doc('${deviceId}_$control')
                .delete();
            print('✅ Firestore에서 삭제 완료: ${deviceId}_$control');
          }
        }
      } catch (e) {
        print('⚠️ Firestore 삭제 실패: $e');
      }

      print('✅ 제스처 매핑 삭제 완료');
      return true;
    } catch (e) {
      print('❌ 제스처 매핑 삭제 오류: $e');
      return false;
    }
  }

  // 🔍 특정 기기에서 사용 중인 제스처 목록 (사용자별)
  static Future<List<String>> getUsedGestures(String deviceId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return [];
      }

      // Firestore에서 사용자별 사용 중인 제스처 조회
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('control_gesture')
          .where('device', isEqualTo: deviceId)
          .get();

      final usedGestures = <String>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final gestureId = data['gesture'] as String? ?? '';
        if (gestureId.isNotEmpty) {
          usedGestures.add(gestureId);
        }
      }

      print('✅ 사용 중인 제스처 조회 완료: ${usedGestures.length}개');
      return usedGestures;
    } catch (e) {
      print('❌ 사용 중인 제스처 조회 오류: $e');
      return [];
    }
  }

  // 🔍 특정 기기에서 사용하지 않는 제스처 목록 (사용자별)
  static Future<List<String>> getUnusedGestures(String deviceId) async {
    try {
      final usedGestures = await getUsedGestures(deviceId);
      final allGestures = getAvailableGestures().keys.toList();
      final unusedGestures = allGestures
          .where((gesture) => !usedGestures.contains(gesture))
          .toList();

      print('✅ 사용하지 않는 제스처 조회 완료: ${unusedGestures.length}개');
      return unusedGestures;
    } catch (e) {
      print('❌ 사용하지 않는 제스처 조회 오류: $e');
      return [];
    }
  }

  // 🔍 기기별 제스처 매핑 조회 (API 우선, Firestore 백업)
  static Future<Map<String, Map<String, String>>> getDeviceGestureMapping(
      String deviceId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return {};
      }

      print('🔍 기기별 제스처 매핑 조회: $deviceId (사용자: $uid)');

      // 백엔드 구조에 맞춰 Realtime Database에서 직접 조회 (control_gesture/{uid}/{mode}/{gesture})
      try {
        final database = FirebaseDatabase.instance;
        final snapshot =
            await database.ref('control_gesture/$uid/$deviceId').once();

        print('📡 RTDB 매핑 조회 응답: ${snapshot.snapshot.exists}');

        if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
          final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
          final mapping = <String, Map<String, String>>{};

          for (final entry in data.entries) {
            final gestureId = entry.key.toString();
            final gestureData = entry.value as Map<dynamic, dynamic>;
            final control = gestureData['control']?.toString() ?? '';

            if (control.isNotEmpty) {
              mapping[gestureId] = {
                'control': control,
                'device': deviceId,
                'gesture': gestureId,
              };
            }
          }

          print('✅ 기기별 제스처 매핑 조회 완료: ${mapping.length}개');
          return mapping;
        } else {
          print('ℹ️ 해당 기기에 설정된 제스처 매핑이 없습니다');
          return {};
        }
      } catch (e) {
        print('❌ 기기별 제스처 매핑 조회 오류: $e');
        return {};
      }
    } catch (e) {
      print('❌ 기기별 제스처 매핑 조회 오류: $e');
      return {};
    }
  }

  // 🔍 제어 제스처 매핑 조회 (사용자별) - 하위 호환성
  static Future<Map<String, String>> getControlGestureMapping(
      String deviceId) async {
    try {
      final mappings = await getDeviceGestureMapping(deviceId);
      final result = <String, String>{};

      for (final entry in mappings.entries) {
        final gestureId = entry.key;
        final data = entry.value;
        final control = data['control'] as String? ?? '';
        if (control.isNotEmpty) {
          result[gestureId] = control;
        }
      }

      return result;
    } catch (e) {
      print('❌ 제어 제스처 매핑 조회 오류: $e');
      return {};
    }
  }

  // 🔍 사용 횟수 증가 (사용자별)
  static Future<bool> incrementGestureUsage(
      String deviceId, String gestureId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      // 문서 ID를 찾기 위해 control_gesture 컬렉션을 검색
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('control_gesture')
          .where('gesture', isEqualTo: gestureId)
          .where('device', isEqualTo: deviceId)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ 사용 횟수를 증가시킬 문서를 찾을 수 없음');
        return false;
      }

      final docId = snapshot.docs.first.id;
      print('📄 사용 횟수 증가할 문서 ID: $docId');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('control_gesture')
          .doc(docId)
          .update({
        'usageCount': FieldValue.increment(1),
        'lastUsed': FieldValue.serverTimestamp(),
      });

      print('✅ 사용 횟수 증가 완료');
      return true;
    } catch (e) {
      print('❌ 사용 횟수 증가 오류: $e');
      return false;
    }
  }

  // 🎭 제스처 아이콘 가져오기
  static String getGestureIcon(String gestureId) {
    final gestures = getAvailableGestures();
    final gesture = gestures[gestureId];
    return gesture?['icon'] ?? '🤚';
  }

  // 🏷️ 제스처 이름 가져오기
  static String getGestureName(String gestureId) {
    final gestures = getAvailableGestures();
    final gesture = gestures[gestureId];
    return gesture?['name'] ?? gestureId;
  }

  // 📝 제스처 설명 가져오기
  static String getGestureDescription(String gestureId) {
    final gestures = getAvailableGestures();
    final gesture = gestures[gestureId];
    return gesture?['description'] ?? '';
  }

  // 🎯 제스처 실행 (사용자별)
  static Future<bool> executeGestureAction(
      String deviceId, String gestureId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return false;
      }

      print('🎯 제스처 실행: $deviceId (사용자: $uid)');
      print('🤚 제스처: $gestureId');

      // 사용 횟수 증가
      await incrementGestureUsage(deviceId, gestureId);

      // 백엔드 API 호출 (선택적)
      try {
        await _callBackendApi('/gesture/execute', {
          'device_id': deviceId,
          'gesture_id': gestureId,
        });
        print('✅ 백엔드 API 호출 완료');
      } catch (e) {
        print('⚠️ 백엔드 API 호출 실패 (무시됨): $e');
      }

      return true;
    } catch (e) {
      print('❌ 제스처 실행 오류: $e');
      return false;
    }
  }

  // 🔍 모드 진입 제스처 조회 (사용자별)
  static Future<String?> getModeEntryGesture(String deviceId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return null;
      }

      print('🔍 모드 진입 제스처 조회: $deviceId (사용자: $uid)');

      // 새로운 구조: gestureKey → {device: "deviceId"} 에서 해당 device를 찾기
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('mode_gesture')
          .where('device', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final gestureKey = doc.id; // 문서 ID가 제스처 키
        print('✅ 모드 진입 제스처 조회 완료: $deviceId → $gestureKey');
        return gestureKey;
      }

      print('ℹ️ 모드 진입 제스처가 설정되지 않았습니다: $deviceId');
      return null;
    } catch (e) {
      print('❌ 모드 진입 제스처 조회 오류: $e');
      return null;
    }
  }

  // 🔧 사용자별 컬렉션 존재 확인 및 생성
  static Future<void> _ensureUserCollectionsExist(String uid) async {
    try {
      print('🔧 사용자별 컬렉션 확인 및 생성 시작: $uid');
      print('🔍 Firestore 인스턴스 확인: ${_firestore != null}');

      // mode_gesture 컬렉션 확인
      print('🔍 mode_gesture 컬렉션 확인 중...');
      try {
        final modeGestureSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('mode_gesture')
            .limit(1)
            .get();

        print('📊 mode_gesture 스냅샷 상태: ${modeGestureSnapshot.docs.isNotEmpty}');
        print('📊 mode_gesture 스냅샷 개수: ${modeGestureSnapshot.docs.length}');

        if (modeGestureSnapshot.docs.isEmpty) {
          print('📁 mode_gesture 컬렉션 생성 중...');
          try {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('mode_gesture')
                .doc('_init')
                .set({'created_at': FieldValue.serverTimestamp()});
            print('✅ mode_gesture 컬렉션 생성 완료');

            // 생성 확인
            final verifySnapshot = await _firestore
                .collection('users')
                .doc(uid)
                .collection('mode_gesture')
                .limit(1)
                .get();
            print('✅ 생성 확인: ${verifySnapshot.docs.isNotEmpty}');
          } catch (e) {
            print('❌ mode_gesture 컬렉션 생성 실패: $e');
            print('❌ 오류 타입: ${e.runtimeType}');
            if (e is FirebaseException) {
              print('❌ Firebase 오류 코드: ${e.code}');
              print('❌ Firebase 오류 메시지: ${e.message}');
            }
            throw e;
          }
        } else {
          print('✅ mode_gesture 컬렉션이 이미 존재합니다');
        }
      } catch (e) {
        print('❌ mode_gesture 컬렉션 확인 실패: $e');
        throw e;
      }

      // control_gesture 컬렉션 확인
      print('🔍 control_gesture 컬렉션 확인 중...');
      try {
        final controlGestureSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('control_gesture')
            .limit(1)
            .get();

        print(
            '📊 control_gesture 스냅샷 상태: ${controlGestureSnapshot.docs.isNotEmpty}');
        print(
            '📊 control_gesture 스냅샷 개수: ${controlGestureSnapshot.docs.length}');

        if (controlGestureSnapshot.docs.isEmpty) {
          print('📁 control_gesture 컬렉션 생성 중...');
          try {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('control_gesture')
                .doc('_init')
                .set({'created_at': FieldValue.serverTimestamp()});
            print('✅ control_gesture 컬렉션 생성 완료');
          } catch (e) {
            print('❌ control_gesture 컬렉션 생성 실패: $e');
            print('❌ 오류 타입: ${e.runtimeType}');
            if (e is FirebaseException) {
              print('❌ Firebase 오류 코드: ${e.code}');
              print('❌ Firebase 오류 메시지: ${e.message}');
            }
            throw e;
          }
        } else {
          print('✅ control_gesture 컬렉션이 이미 존재합니다');
        }
      } catch (e) {
        print('❌ control_gesture 컬렉션 확인 실패: $e');
        throw e;
      }

      print('✅ 모든 컬렉션 확인 및 생성 완료');
    } catch (e) {
      print('❌ 사용자별 컬렉션 생성 오류: $e');
      print('❌ 오류 타입: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Firebase 오류 코드: ${e.code}');
        print('❌ Firebase 오류 메시지: ${e.message}');
      }
      throw e;
    }
  }

  // 🌐 백엔드 API 호출
  static Future<void> _callBackendApi(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://5daf32736a31.ngrok-free.app$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ 백엔드 API 응답 성공: ${response.body}');
      } else {
        print('⚠️ 백엔드 API 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 백엔드 API 호출 오류: $e');
      throw e;
    }
  }

  // 🌐 백엔드 API에서 매핑된 컨트롤 조회
  static Future<List<String>> _getMappedControlsFromBackend(
      String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://5daf32736a31.ngrok-free.app/dashboard/mapped_controls?device_id=$deviceId'),
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final controls = data['controls'] as List<dynamic>? ?? [];
        return controls.map((control) => control.toString()).toList();
      } else {
        print('⚠️ 백엔드 API 응답 오류: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 백엔드 API 호출 오류: $e');
      return [];
    }
  }

  // 🌐 백엔드 API에서 제스처 목록 가져오기
  static Future<Map<String, Map<String, dynamic>>>
      getAvailableGesturesFromAPI() async {
    try {
      print('🌐 API에서 제스처 목록 가져오는 중...');
      final response = await http.get(
        Uri.parse('https://5daf32736a31.ngrok-free.app/gesture/list'),
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final gestures = data['gestures'] as Map<String, dynamic>? ?? {};

        final result = <String, Map<String, dynamic>>{};
        for (final entry in gestures.entries) {
          if (entry.value is Map<String, dynamic>) {
            result[entry.key] = entry.value as Map<String, dynamic>;
          } else {
            // 단순 문자열인 경우 기본 구조로 변환
            result[entry.key] = {
              'name': entry.value.toString(),
              'description': '',
              'icon': '🤚',
            };
          }
        }

        print('✅ API에서 제스처 목록 가져오기 완료: ${result.length}개');
        return result;
      } else {
        print('⚠️ API 응답 오류: ${response.statusCode}');
        return getAvailableGestures(); // 기본 제스처 목록 반환
      }
    } catch (e) {
      print('❌ API 호출 오류: $e');
      return getAvailableGestures(); // 기본 제스처 목록 반환
    }
  }

  // 📱 Firestore에 백업 저장 (내부 메서드)
  static Future<void> _saveToFirestore(String uid, String deviceId,
      String gestureId, String control, String label) async {
    try {
      // 사용자 컬렉션 존재 확인
      await _ensureUserCollectionsExist(uid);

      // 문서 ID: deviceId_control 형태로 생성 (예: light_power)
      final docId = '${deviceId}_$control';
      print('📄 문서 ID 생성: $docId');

      // 저장할 데이터 준비 (이미지와 동일한 구조)
      final dataToSave = {
        'control': control,
        'device': deviceId,
        'gesture': gestureId,
      };

      // Firestore에 저장
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('control_gesture')
          .doc(docId)
          .set(dataToSave);

      print('✅ Firestore 백업 저장 완료');
    } catch (e) {
      print('❌ Firestore 백업 저장 오류: $e');
    }
  }
}
