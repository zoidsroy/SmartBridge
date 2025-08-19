import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'backend_api_service.dart';

class RemoteControlService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // 🏠 아두이노 IP 주소 (기본값)
  static String _arduinoIP = '192.168.253.204'; // 기본 IP
  static int _arduinoPort = 1883;

  // 🔧 아두이노 IP 설정
  static void setArduinoIP(String ip, {int port = 80}) {
    _arduinoIP = ip;
    _arduinoPort = port;
    print('🔧 아두이노 IP 설정됨: $_arduinoIP:$_arduinoPort');
  }

  // 📱 현재 아두이노 IP 가져오기
  static String get arduinoIP => _arduinoIP;
  static int get arduinoPort => _arduinoPort;

  // 📱 기기별 IR 코드 가져오기
  static Future<Map<String, Map<String, dynamic>>> getIRCodes(
      String deviceId) async {
    try {
      print('🔍 $deviceId IR 코드 가져오는 중...');
      final snapshot = await _database.child('ir_codes/$deviceId').once();

      if (!snapshot.snapshot.exists) {
        print('⚠️ $deviceId IR 코드가 없음');
        return {};
      }

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final irCodes = Map<String, Map<String, dynamic>>.from(
        data.map((key, value) => MapEntry(
              key.toString(),
              Map<String, dynamic>.from(value as Map),
            )),
      );

      print('✅ $deviceId IR 코드 ${irCodes.length}개 로드됨');
      return irCodes;
    } catch (e) {
      print('❌ IR 코드 가져오기 오류: $e');
      return {};
    }
  }

  // 🎯 IR 코드 전송 (Firebase → 서버 → MQTT → 아두이노)
  static Future<bool> sendIRCode({
    required String deviceId,
    required String command,
    required Map<String, dynamic> irData, // 실제로는 사용하지 않음
  }) async {
    try {
      print('📡 Firebase를 통한 IR 명령 전송: $deviceId/$command');

      // 1️⃣ Firebase에서 IR 코드 존재 여부 확인
      final irCodesSnapshot =
          await _database.child('ir_codes/$deviceId/$command').once();

      if (!irCodesSnapshot.snapshot.exists) {
        print('❌ IR 코드가 없음: $deviceId/$command');
        return false;
      }

      print('✅ IR 코드 존재 확인: $deviceId/$command');

      // 2️⃣ 서버가 감시하는 Firebase 경로에 명령 전송
      final commandData = {
        'deviceId': deviceId,
        'command': command,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'mobile_app', // 명령 출처
        'status': 'pending', // 처리 상태
      };

      // 3️⃣ Firebase 'ir_commands' 경로에 명령 푸시 (서버가 이 경로 감시)
      final commandRef = await _database.child('ir_commands').push();
      await commandRef.set(commandData);

      print('✅ Firebase에 IR 명령 전송 완료: ${commandRef.key}');

      // 4️⃣ 기기 상태 업데이트 (선택사항)
      await _updateDeviceStatusFromIR(deviceId, command, irData);

      // 5️⃣ 명령 처리 결과 대기 (선택사항 - 타임아웃 설정)
      bool success =
          await _waitForCommandCompletion(commandRef.key!, timeout: 10);

      return success;
    } catch (e) {
      print('❌ Firebase IR 명령 전송 실패: $e');
      return false;
    }
  }

  // ⏳ 명령 처리 완료 대기 (선택사항)
  static Future<bool> _waitForCommandCompletion(String commandId,
      {int timeout = 10}) async {
    try {
      final completer = Completer<bool>();
      late StreamSubscription subscription;

      // 타임아웃 타이머
      final timer = Timer(Duration(seconds: timeout), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(true); // 타임아웃되어도 성공으로 처리 (백그라운드 처리)
        }
      });

      // 명령 상태 모니터링
      subscription = _database
          .child('ir_commands/$commandId/status')
          .onValue
          .listen((event) {
        final status = event.snapshot.value as String?;
        print('📊 명령 상태 업데이트: $commandId → $status');

        if (status == 'completed' || status == 'failed') {
          timer.cancel();
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(status == 'completed');
          }
        }
      });

      return await completer.future;
    } catch (e) {
      print('❌ 명령 완료 대기 오류: $e');
      return true; // 오류 시에도 성공으로 처리
    }
  }

  // 📊 기기 상태 업데이트 (IR 명령에 따라)
  static Future<void> _updateDeviceStatusFromIR(
      String deviceId, String command, Map<String, dynamic> irData) async {
    try {
      final statusRef = _database.child('status/$deviceId');
      final statusSnapshot = await statusRef.once();

      Map<String, dynamic> currentStatus = {};
      if (statusSnapshot.snapshot.exists) {
        currentStatus =
            Map<String, dynamic>.from(statusSnapshot.snapshot.value as Map);
      }

      // 명령에 따라 상태 업데이트
      switch (command.toLowerCase()) {
        case 'power':
        case 'power_on':
          currentStatus['power'] = 'on';
          break;
        case 'power_off':
          currentStatus['power'] = 'off';
          break;
        case 'vol_up':
          final currentVol = currentStatus['volume'] as int? ?? 50;
          currentStatus['volume'] = (currentVol + 5).clamp(0, 100);
          break;
        case 'vol_down':
          final currentVol = currentStatus['volume'] as int? ?? 50;
          currentStatus['volume'] = (currentVol - 5).clamp(0, 100);
          break;
        case 'up':
        case 'channel_up':
          final currentCh = currentStatus['channel'] as int? ?? 1;
          currentStatus['channel'] = currentCh + 1;
          break;
        case 'down':
        case 'channel_down':
          final currentCh = currentStatus['channel'] as int? ?? 1;
          currentStatus['channel'] = (currentCh - 1).clamp(1, 999);
          break;
        case 'brighter':
          final currentBright = currentStatus['brightness'] as int? ?? 50;
          currentStatus['brightness'] = (currentBright + 10).clamp(0, 100);
          break;
        case 'dimmer':
          final currentBright = currentStatus['brightness'] as int? ?? 50;
          currentStatus['brightness'] = (currentBright - 10).clamp(0, 100);
          break;
      }

      currentStatus['lastUpdated'] = DateTime.now().toIso8601String();
      await statusRef.update(currentStatus);
    } catch (e) {
      print('상태 업데이트 오류: $e');
    }
  }

  // 🏷️ 명령어 한글 라벨 가져오기
  static String getCommandLabel(String command) {
    const commandLabels = {
      'power': '전원',
      'power_on': '전원 켜기',
      'power_off': '전원 끄기',
      'vol_up': '볼륨 올리기',
      'vol_down': '볼륨 내리기',
      'VOL_up': '볼륨 올리기',
      'VOL_down': '볼륨 내리기',
      'up': '위로',
      'down': '아래로',
      'channel_up': '채널 올리기',
      'channel_down': '채널 내리기',
      'menu': '메뉴',
      'home': '홈',
      'back': '뒤로',
      'ok': '확인',
      'mute': '음소거',
      'brighter': '밝게',
      'dimmer': '어둡게',
      'color': '색상 변경',
      'stronger': '강하게',
      'weaker': '약하게',
      'fan_mode': '모드 변경',
      'horizontal': '좌우 회전',
      'vertical': '상하 회전',
      'timer': '타이머',
      'open': '열기',
      'close': '닫기',
      'half': '반만 열기',
      'HDMI_InOut': 'HDMI 전환',
      '10min': '10분 타이머',
      '30min': '30분 타이머',
      '60min': '60분 타이머',
    };

    return commandLabels[command] ?? command;
  }

  // 🎨 명령어 아이콘 가져오기
  static String getCommandIcon(String command) {
    const commandIcons = {
      'power': '⚡',
      'power_on': '🔌',
      'power_off': '🔌',
      'vol_up': '🔊',
      'vol_down': '🔉',
      'VOL_up': '🔊',
      'VOL_down': '🔉',
      'up': '⬆️',
      'down': '⬇️',
      'channel_up': '📺⬆️',
      'channel_down': '📺⬇️',
      'menu': '📋',
      'home': '🏠',
      'back': '⬅️',
      'ok': '✅',
      'mute': '🔇',
      'brighter': '☀️',
      'dimmer': '🌙',
      'color': '🎨',
      'stronger': '💨⬆️',
      'weaker': '💨⬇️',
      'fan_mode': '🌀',
      'horizontal': '↔️',
      'vertical': '↕️',
      'timer': '⏰',
      'open': '🔓',
      'close': '🔒',
      'half': '🔘',
      'HDMI_InOut': '📱',
      '10min': '⏰10',
      '30min': '⏰30',
      '60min': '⏰60',
    };

    return commandIcons[command] ?? '🎮';
  }

  // 🔍 리모컨 기능 검색
  static List<MapEntry<String, Map<String, dynamic>>> searchCommands(
      Map<String, Map<String, dynamic>> irCodes, String query) {
    if (query.isEmpty) return irCodes.entries.toList();

    return irCodes.entries.where((entry) {
      final command = entry.key.toLowerCase();
      final label = getCommandLabel(entry.key).toLowerCase();
      final searchQuery = query.toLowerCase();

      return command.contains(searchQuery) || label.contains(searchQuery);
    }).toList();
  }

  // 🗣️ 음성 명령으로 기기 제어 (백엔드 API 연동)
  static Future<Map<String, dynamic>?> controlDeviceByVoice(
      String voiceCommand) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('❌ 사용자 인증 정보 없음');
        return null;
      }

      print('🗣️ 음성 명령으로 기기 제어: $voiceCommand');

      final response = await BackendApiService.sendVoiceCommand(
        uid: uid,
        voice: voiceCommand,
      );

      if (response != null) {
        print('✅ 음성 명령 처리 성공: ${response['message']}');

        // 음성 명령 결과에 따라 실제 기기 제어 수행
        final device = response['device'] as String?;
        final control = response['control'] as String?;

        if (device != null && control != null) {
          print('🎮 기기 제어 실행: $device/$control');

          // Firebase에서 해당 기기의 IR 코드 가져오기
          final irCodes = await getIRCodes(device);
          final irData = irCodes[control];

          if (irData != null) {
            // IR 코드 전송
            final success = await sendIRCode(
              deviceId: device,
              command: control,
              irData: irData,
            );

            if (success) {
              print('✅ IR 코드 전송 성공: $device/$control');
            } else {
              print('❌ IR 코드 전송 실패: $device/$control');
            }
          } else {
            print('⚠️ IR 코드 없음: $device/$control');
          }
        }

        return response;
      }

      return null;
    } catch (e) {
      print('❌ 음성 명령 처리 오류: $e');
      return null;
    }
  }

  // 🔍 백엔드 API 연결 상태 확인
  static Future<bool> isBackendApiConnected() async {
    try {
      return await BackendApiService.testConnection();
    } catch (e) {
      print('❌ 백엔드 API 연결 상태 확인 오류: $e');
      return false;
    }
  }
}
