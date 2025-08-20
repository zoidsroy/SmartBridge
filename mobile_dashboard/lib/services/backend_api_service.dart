import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendApiService {
  // 🔗 백엔드 서버 URL (실제 서버 주소로 변경 필요)
  static const String _baseUrl =
      'https://23ec43836f15.ngrok-free.app'; // ngrok 주소
  // static const String _baseUrl = 'http://your-server-ip:5000'; // 실제 서버

  // 🔗 API URL getter
  static String get apiUrl => _baseUrl;

  // ⏱️ 타임아웃 설정
  static const Duration _timeout = Duration(seconds: 10);

  // 🔐 공통 헤더 (ngrok 브라우저 경고 우회)
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // ngrok 브라우저 경고 우회
      };

  // 🎯 제스처 제어 API (/gesture)
  static Future<Map<String, dynamic>?> sendGesture({
    required String uid,
    required String gesture,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/gesture');
      final body = json.encode({
        'uid': uid,
        'gesture': gesture,
      });

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 제스처 제어 API 오류: $e');
      rethrow;
    }
  }

  // 🗣️ 음성 인식 API (/voice)
  static Future<Map<String, dynamic>?> sendVoiceCommand({
    required String uid,
    required String voice,
  }) async {
    try {
      print('🗣️ 음성 인식 API 호출: $voice');

      final uri = Uri.parse('$_baseUrl/voice');
      final body = json.encode({
        'uid': uid,
        'voice': voice,
      });

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);

      print('📡 음성 API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ 음성 인식 성공: ${data['message']}');
        return data;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 음성 인식 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 음성 인식 API 오류: $e');
      rethrow;
    }
  }

  // 📊 커스터마이징 API - 매핑되지 않은 컨트롤 조회
  static Future<List<String>> getUnmappedControls({
    required String uid,
    required String mode,
  }) async {
    try {
      print('📊 매핑되지 않은 컨트롤 조회: $mode');

      final uri = Uri.parse('$_baseUrl/dashboard/unmapped_controls')
          .replace(queryParameters: {
        'uid': uid,
        'mode': mode,
      });

      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(_timeout);

      print('📡 컨트롤 조회 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final controls = data.cast<String>();
        print('✅ 매핑되지 않은 컨트롤 ${controls.length}개 조회 성공');
        return controls;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 컨트롤 조회 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 컨트롤 조회 API 오류: $e');
      rethrow;
    }
  }

  // 📊 커스터마이징 API - 매핑된 컨트롤 조회
  static Future<List<String>> getMappedControls({
    required String uid,
    required String mode,
  }) async {
    try {
      print('📊 매핑된 컨트롤 조회: $mode');

      final uri = Uri.parse('$_baseUrl/dashboard/mapped_controls')
          .replace(queryParameters: {
        'uid': uid,
        'mode': mode,
      });

      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(_timeout);

      print('📡 매핑된 컨트롤 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final controls = data.cast<String>();
        print('✅ 매핑된 컨트롤 ${controls.length}개 조회 성공');
        return controls;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 매핑된 컨트롤 조회 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 매핑된 컨트롤 조회 API 오류: $e');
      rethrow;
    }
  }

  // 📊 커스터마이징 API - 매핑되지 않은 제스처 조회
  static Future<List<String>> getUnmappedGestures({
    required String uid,
    required String mode,
  }) async {
    try {
      print('📊 매핑되지 않은 제스처 조회: $mode');

      final uri = Uri.parse('$_baseUrl/dashboard/unmapped_gestures')
          .replace(queryParameters: {
        'uid': uid,
        'mode': mode,
      });

      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(_timeout);

      print('📡 제스처 조회 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final gestures = data.cast<String>();
        print('✅ 매핑되지 않은 제스처 ${gestures.length}개 조회 성공');
        return gestures;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 제스처 조회 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 제스처 조회 API 오류: $e');
      rethrow;
    }
  }

  // 🔗 커스터마이징 API - 제스처-컨트롤 매핑 등록
  static Future<bool> registerMapping({
    required String uid,
    required String gesture,
    required String control,
    required String mode,
  }) async {
    try {
      print('🔗 제스처-컨트롤 매핑 등록: $gesture → $control ($mode)');

      final uri = Uri.parse('$_baseUrl/dashboard/register_mapping');
      final body = json.encode({
        'uid': uid,
        'gesture': gesture,
        'control': control,
        'mode': mode,
      });

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);

      print('📡 매핑 등록 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ 매핑 등록 성공: ${data['message']}');
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 매핑 등록 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 매핑 등록 API 오류: $e');
      rethrow;
    }
  }

  // 🔄 커스터마이징 API - 제스처-컨트롤 매핑 수정
  static Future<bool> updateMapping({
    required String uid,
    required String mode,
    required String newGesture,
    required String control,
  }) async {
    try {
      print('🔄 제스처-컨트롤 매핑 수정: $newGesture → $control ($mode)');

      final uri = Uri.parse('$_baseUrl/dashboard/update_mapping');
      final body = json.encode({
        'uid': uid,
        'mode': mode,
        'new_gesture': newGesture,
        'control': control,
      });

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);

      print('📡 매핑 수정 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ 매핑 수정 성공: ${data['message']}');
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 매핑 수정 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 매핑 수정 API 오류: $e');
      rethrow;
    }
  }

  // 🔍 커스터마이징 API - 특정 모드의 제스처-컨트롤 매핑 조회
  static Future<Map<String, Map<String, String>>> getMappings({
    required String uid,
    required String mode,
  }) async {
    try {
      print('🔍 제스처-컨트롤 매핑 조회: $mode');

      final uri = Uri.parse('$_baseUrl/dashboard/get_mappings')
          .replace(queryParameters: {
        'uid': uid,
        'mode': mode,
      });

      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(_timeout);

      print('📡 매핑 조회 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final mappings = Map<String, Map<String, String>>.from(
          data.map((key, value) => MapEntry(
                key,
                Map<String, String>.from(value as Map),
              )),
        );
        print('✅ 매핑 조회 성공: ${mappings.length}개');
        return mappings;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print('❌ 매핑 조회 실패: ${errorData['error']}');
        throw Exception(errorData['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      print('💥 매핑 조회 API 오류: $e');
      rethrow;
    }
  }

  // 🤖 추천 시스템 API
  static Future<Map<String, dynamic>?> getRecommendations({
    required String uid,
  }) async {
    try {
      print('🤖 추천 시스템 API 호출');

      final uri = Uri.parse('$_baseUrl/recommend_gesture_voice_auto')
          .replace(queryParameters: {'uid': uid});

      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(_timeout);

      print('📡 추천 API 응답: ${response.statusCode}');
      print('🔗 요청 URL: $uri');
      print('🔍 응답 헤더: ${response.headers}');
      print(
          '📄 응답 내용 (처음 300자): ${response.body.length > 300 ? response.body.substring(0, 300) + '...' : response.body}');

      if (response.statusCode == 200) {
        // JSON 파싱 전에 응답이 실제로 JSON인지 확인
        if (response.headers['content-type']?.contains('application/json') !=
            true) {
          print('❌ 응답이 JSON이 아님: ${response.headers['content-type']}');
          throw Exception('서버가 HTML을 반환했습니다. ngrok URL을 확인하세요.');
        }

        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          print('✅ 추천 데이터 수신 성공: ${data['recommendations']?.length ?? 0}개');
          return data;
        } catch (e) {
          print('💥 JSON 파싱 실패: $e');
          throw Exception('서버 응답을 해석할 수 없습니다: $e');
        }
      } else {
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          print('❌ 추천 데이터 수신 실패: ${errorData['error']}');
          throw Exception(errorData['error'] ?? '알 수 없는 오류');
        } catch (e) {
          print('💥 오류 응답 파싱 실패: $e');
          throw Exception(
              'HTTP ${response.statusCode}: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}');
        }
      }
    } catch (e) {
      print('💥 추천 시스템 API 오류: $e');
      rethrow;
    }
  }

  // 🔍 서버 연결 테스트
  static Future<bool> testConnection() async {
    try {
      print('🔍 백엔드 서버 연결 테스트 중...');

      final uri = Uri.parse('$_baseUrl/recommend_gesture_voice_auto');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );

      final isConnected =
          response.statusCode == 200 || response.statusCode == 400;
      print(isConnected ? '✅ 서버 연결 성공!' : '❌ 서버 연결 실패');

      return isConnected;
    } catch (e) {
      print('💥 서버 연결 실패: $e');
      return false;
    }
  }

  // 🌡️ 서버 상태 체크
  static Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final isConnected = await testConnection();

      return {
        'connected': isConnected,
        'baseUrl': _baseUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'timeout': _timeout.inSeconds,
      };
    } catch (e) {
      return {
        'connected': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
