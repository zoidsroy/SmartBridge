import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'dart:io'; // Flutter Web에서는 사용 불가하므로 제거

class RecommendationApiService {
  // ngrok URL - 실제 ngrok URL로 업데이트 필요
  static const String _baseUrl =
      'https://7fa0-2001-e60-1065-e213-c941-1534-3ceb-e97a.ngrok-free.app';
  static const String _recommendEndpoint = '/recommend_gesture_auto';

  // 전체 API URL
  static String get apiUrl => '$_baseUrl$_recommendEndpoint';

  /// 자동 제스처 추천 API 호출
  static Future<Map<String, dynamic>?> getGestureRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // ngrok의 경우 브라우저 경고를 우회하기 위한 헤더
          'ngrok-skip-browser-warning': 'true',
          'User-Agent': 'FlutterApp/1.0',
          // CORS 관련 헤더 추가 (실제로는 서버에서 설정해야 함)
          'Origin': 'https://flutter-web-app',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ).timeout(
        const Duration(seconds: 15), // 타임아웃을 15초로 증가
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return data;
        } catch (parseError) {
          print('❌ JSON 파싱 오류: $parseError');
          print('📋 원본 응답: ${response.body.substring(0, 200)}...');
          print('📋 테스트용 샘플 데이터를 사용합니다.');
          return _getSampleData();
        }
      } else {
        print('❌ API 호출 실패: ${response.statusCode}');
        print('❌ 오류 내용: ${response.body}');
        print('📋 테스트용 샘플 데이터를 사용합니다.');
        return _getSampleData(); // 테스트용 샘플 데이터 반환
      }
    } catch (e) {
      print('❌ API 호출 중 예외 발생: $e');
      if (e.toString().contains('Failed to fetch')) {
        print('🔧 Flutter Web CORS 문제 감지');
        print('🔧 브라우저 보안 정책으로 인한 차단');
        print('🔧 해결책: Python Flask 서버에 CORS 설정 필요');
      }
      print('📋 테스트용 샘플 데이터를 사용합니다.');
      return _getSampleData(); // 테스트용 샘플 데이터 반환
    }
  }

  /// 테스트용 샘플 데이터 (실제 API 응답 구조와 동일)
  static Map<String, dynamic> _getSampleData() {
    return {
      "source": "sample", // 샘플 데이터 구분용 마커
      "recommendations": [
        {
          "device": "light",
          "reason": "light 모드 진입을 추천해요!",
          "recommended_gesture": "one"
        },
        {
          "device": "light",
          "reason": "당신의 생활패턴에 딱 맞는 추천입니다.",
          "recommended_gesture": "small_heart"
        },
        {
          "device": "projector",
          "reason": "projector 모드 진입을 추천해요!",
          "recommended_gesture": "two"
        },
        {
          "device": "projector",
          "reason": "당신의 생활패턴에 딱 맞는 추천입니다.",
          "recommended_gesture": "small_heart"
        },
        {
          "device": "curtain",
          "reason": "curtain 모드 진입을 추천해요!",
          "recommended_gesture": "three"
        },
        {
          "device": "curtain",
          "reason": "당신의 생활패턴에 딱 맞는 추천입니다.",
          "recommended_gesture": "small_heart"
        }
      ],
      "timestamp": DateTime.now().toIso8601String(),
    };
  }

  /// API URL 업데이트 (ngrok URL이 변경될 때 사용)
  static String updateNgrokUrl(String newNgrokUrl) {
    // 새로운 ngrok URL로 업데이트하는 기능
    // 실제로는 환경변수나 설정 파일에서 관리하는 것이 좋습니다
    return '$newNgrokUrl$_recommendEndpoint';
  }

  /// API 연결 테스트
  static Future<bool> testConnection() async {
    try {
      print('🔍 API 연결 테스트 시작...');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(
        const Duration(seconds: 5),
      );

      bool isConnected = response.statusCode == 200;
      print(isConnected ? '✅ API 연결 성공' : '❌ API 연결 실패');

      return isConnected;
    } catch (e) {
      print('❌ API 연결 테스트 실패: $e');
      return false;
    }
  }

  /// 추천 데이터를 Flutter에서 사용하기 쉬운 형태로 변환
  static List<RecommendationItem> parseRecommendations(
      Map<String, dynamic> apiResponse) {
    try {
      List<RecommendationItem> recommendations = [];

      // 실제 API 응답 구조: {"recommendations": [...], "timestamp": "..."}
      final recommendationsData = apiResponse['recommendations'] as List?;

      if (recommendationsData != null) {
        for (var item in recommendationsData) {
          if (item is Map<String, dynamic>) {
            recommendations.add(RecommendationItem.fromApi(item));
          }
        }
      }

      print('📋 파싱된 추천 항목 수: ${recommendations.length}');
      return recommendations;
    } catch (e) {
      print('❌ 추천 데이터 파싱 오류: $e');
      return [];
    }
  }
}

/// API에서 받은 추천 데이터를 담는 클래스
class RecommendationItem {
  final String gestureId;
  final String gestureName;
  final String deviceId;
  final String deviceName;
  final String action;
  final String description;
  final double confidence; // 추천 신뢰도
  final String reason; // 추천 이유

  RecommendationItem({
    required this.gestureId,
    required this.gestureName,
    required this.deviceId,
    required this.deviceName,
    required this.action,
    required this.description,
    required this.confidence,
    required this.reason,
  });

  /// API 응답에서 RecommendationItem 생성
  factory RecommendationItem.fromApi(Map<String, dynamic> json) {
    // 기기 이름 매핑
    final deviceId = json['device']?.toString() ?? '';
    final deviceName = _getDeviceName(deviceId);

    // 제스처 이름 매핑
    final gestureId = json['recommended_gesture']?.toString() ?? '';
    final gestureName = _getGestureName(gestureId);

    // 기본 동작 설정
    final action = _getDefaultAction(deviceId);

    return RecommendationItem(
      gestureId: gestureId,
      gestureName: gestureName,
      deviceId: deviceId,
      deviceName: deviceName,
      action: action,
      description: '${gestureName}로 ${deviceName}을(를) 제어하세요',
      confidence: 0.85, // API에서 신뢰도를 제공하지 않으므로 기본값 설정
      reason: json['reason']?.toString() ?? '',
    );
  }

  /// 기기 ID를 한글 이름으로 변환
  static String _getDeviceName(String deviceId) {
    const deviceNames = {
      'light': '전등',
      'projector': '빔프로젝터',
      'curtain': '커튼',
      'fan': '선풍기',
      'tv': '텔레비전',
    };
    return deviceNames[deviceId] ?? deviceId;
  }

  /// 제스처 ID를 한글 이름으로 변환
  static String _getGestureName(String gestureId) {
    const gestureNames = {
      'one': '1️⃣ 검지',
      'two': '2️⃣ 브이',
      'three': '3️⃣ 세 손가락',
      'four': '4️⃣ 네 손가락',
      'thumbs_up': '👍 좋아요',
      'thumbs_down': '👎 싫어요',
      'thumbs_right': '👉 오른쪽',
      'thumbs_left': '👈 왼쪽',
      'ok': '👌 오케이',
      'promise': '🤙 약속',
      'clockwise': '⏰ 시계방향 회전',
      'counter_clockwise': '🔄 반시계방향 회전',
      'slide_left': '👈 손바닥 왼쪽 슬라이드',
      'slide_right': '👉 손바닥 오른쪽 슬라이드',
      'spider_man': '🕷️ 스파이더맨',
      'small_heart': '💖 작은 하트',
      'vertical_V': '✌️ 세로 브이',
      'horizontal_V': '✌️ 가로 브이',
    };
    return gestureNames[gestureId] ?? gestureId;
  }

  /// 기기별 기본 동작 설정
  static String _getDefaultAction(String deviceId) {
    const defaultActions = {
      'light': '켜기/끄기',
      'projector': '켜기/끄기',
      'curtain': '열기/닫기',
      'fan': '켜기/끄기',
      'tv': '켜기/끄기',
    };
    return defaultActions[deviceId] ?? '제어';
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'gesture_id': gestureId,
      'gesture_name': gestureName,
      'device_id': deviceId,
      'device_name': deviceName,
      'action': action,
      'description': description,
      'confidence': confidence,
      'reason': reason,
    };
  }
}
