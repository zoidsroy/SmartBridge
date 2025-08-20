import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot_smarthome/push_notification.dart';
import 'package:iot_smarthome/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'device_detail_screen.dart';
import 'device_list_screen.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'screens/search_screen.dart';
import 'screens/recommendation_screen.dart';
import 'screens/gesture_customization_screen.dart';
import 'screens/mode_gesture_customization_screen.dart';
import 'screens/usage_analytics_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/user_profile_screen.dart';
import 'screens/find_account_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.notification != null) {
    // Notification received
  }
}

//interact with push alarm msg
Future<void> setupInteractedMessage() async {
  //terminate state
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }
  //background state
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
}

//handle received data from FCM /move on to message screen and show data
void _handleMessage(RemoteMessage message) {
  Future.delayed(const Duration(seconds: 1), () {
    navigatorKey.currentState!.pushNamed('/', arguments: message);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeManager.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  ////////// admob //////////////////////////
  //MobileAds.instance.initialize();
  ////////////////////////////////////////////
  if (!kIsWeb) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS 권한 요청
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      provisional: false,
    );
  }
  //init FCM push alarm
  PushNotification.init();
  //flutter_local_notifications package init
  PushNotification.localNotiInit();
  //background alarm receive listener
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  //foreground alarm receive listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    String payloadData = jsonEncode(message.data);
    // Got a message in foreground
    if (message.notification != null) {
      //flutter_local_notifications package
      PushNotification.showSimpleNotification(
          title: message.notification!.title!,
          body: message.notification!.body!,
          payload: payloadData);
    }
  });
  //interaction function call
  setupInteractedMessage();
  ////////////////////////////////////////////
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppThemeManager().theme,
      navigatorKey: navigatorKey,
      locale: const Locale('ko'),
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null && locale.languageCode == 'ko') {
          return const Locale('ko');
        }
        return const Locale('en');
      },
      builder: (context, child) {
        // 🔹 글자 크기 고정 + 키보드 자동 닫힘 적용
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // 키보드 닫기
          behavior: HitTestBehavior.translucent, // 빈 공간도 인식
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: kIsWeb
                ? Center(
                    child: Container(
                      width: 390, // iPhone 14 Pro 기준 너비
                      height: 844, // iPhone 14 Pro 기준 높이로 고정
                      constraints: const BoxConstraints(
                        maxWidth: 430, // 최대 너비 제한
                        maxHeight: 900, // 최대 높이 제한
                        minHeight: 700, // 최소 높이
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12), // 둥근 모서리 추가
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12), // 컨테이너와 같은 둥근 모서리
                        child: child!,
                      ),
                    ),
                  )
                : child!,
          ),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const AuthWrapper();
            break;

          case '/main_screen':
            page = const MainScreen();
            break;
          case '/device_detail_screen':
            final args = settings.arguments as Map<String, dynamic>;
            page = DeviceDetailScreen(
              label: args['label'],
              keyName: args['key'],
              iconPath: args['iconPath'],
            );
            break;
          case '/search':
            final args = settings.arguments as Map<String, dynamic>?;
            page = SearchScreen(initialQuery: args?['query'] ?? '');
            break;
          case '/recommendation':
            page = const RecommendationScreen();
            break;
          case '/gesture_customization':
            final args = settings.arguments as Map<String, dynamic>?;

            // Arguments 검증 및 디버깅
            print('🔍 gesture_customization 라우트 호출');
            print('🔍 전달받은 arguments: $args');

            if (args == null) {
              print('❌ arguments가 null입니다');
              // 기본 화면으로 리다이렉트하거나 에러 화면 표시
              page = Scaffold(
                appBar: AppBar(title: const Text('오류')),
                body: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('잘못된 접근입니다.\n홈 화면에서 다시 시도해주세요.'),
                    ],
                  ),
                ),
              );
              break;
            }

            final keyName = args['keyName'] as String?;
            final deviceName = args['deviceName'] as String?;

            print('🔍 keyName: $keyName');
            print('🔍 deviceName: $deviceName');

            if (keyName == null || keyName.isEmpty) {
              print('❌ keyName이 null이거나 비어있습니다');
              // 기기 선택 화면으로 리다이렉트
              page = Scaffold(
                appBar: AppBar(title: const Text('기기 선택 필요')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.devices, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('기기를 선택해주세요'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/main_screen',
                            (route) => false,
                          );
                        },
                        child: const Text('홈으로 이동'),
                      ),
                    ],
                  ),
                ),
              );
              break;
            }

            page = GestureCustomizationScreen(
              keyName: keyName,
              deviceName: deviceName ?? '알 수 없는 기기',
            );
            break;
          case '/mode_gesture_customization':
            final args = settings.arguments as Map<String, dynamic>?;

            // Arguments 검증 및 디버깅
            print('🔍 mode_gesture_customization 라우트 호출');
            print('🔍 전달받은 arguments: $args');

            if (args == null) {
              print('❌ arguments가 null입니다');
              // 기본 화면으로 리다이렉트하거나 에러 화면 표시
              page = Scaffold(
                appBar: AppBar(title: const Text('오류')),
                body: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('잘못된 접근입니다.\n홈 화면에서 다시 시도해주세요.'),
                    ],
                  ),
                ),
              );
              break;
            }

            final keyName = args['keyName'] as String?;
            final deviceName = args['deviceName'] as String?;

            print('🔍 keyName: $keyName');
            print('🔍 deviceName: $deviceName');

            if (keyName == null || keyName.isEmpty) {
              print('❌ keyName이 null이거나 비어있습니다');
              // 기기 선택 화면으로 리다이렉트
              page = Scaffold(
                appBar: AppBar(title: const Text('기기 선택 필요')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.devices, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('기기를 선택해주세요'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/main_screen',
                            (route) => false,
                          );
                        },
                        child: const Text('홈으로 이동'),
                      ),
                    ],
                  ),
                ),
              );
              break;
            }

            page = ModeGestureCustomizationScreen(
              keyName: keyName,
              deviceName: deviceName ?? '알 수 없는 기기',
            );
            break;
          case '/usage_analytics':
            page = const UsageAnalyticsScreen();
            break;
          case '/user_profile':
            page = const UserProfileScreen();
            break;
          case '/find_account':
            page = const FindAccountScreen();
            break;
          default:
            return null;
        }

        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _permissionHandler();
    _navigateToNextScreen();
  }

  void _permissionHandler() async {
    if (!kIsWeb && Platform.isIOS) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.notification,
        // Permission.storage,
        // Permission.photos,
      ].request();
    } else {
      // Android & Web
      Map<Permission, PermissionStatus> statuses = await [
        Permission.notification,
        //Permission.storage,
        //Permission.photos,
      ].request();
    }
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      String? fcmToken;
      if (!kIsWeb && Platform.isIOS) {
        NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken !=
              '66616B652D61706E732D746F6B656E2D666F722D73696D756C61746F72') {
            fcmToken = await FirebaseMessaging.instance.getToken();
          }
        }
      } else if (!kIsWeb && Platform.isAndroid) {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        final ref = FirebaseDatabase.instance.ref('user_info');
        await ref.update({
          'fcmToken': fcmToken,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('FCM Token Error: $e');
      // FCM 에러는 무시하고 계속 진행
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main_screen',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManager().colorSet.greyishWhite,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 전체 배경 이미지
          Image.asset(
            'assets/icons/loading.png',
            fit: BoxFit.cover,
          ),
          // 로고 오버레이
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Image.asset(
                  'assets/icons/logo.png',
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;

  final PageController _pageController = PageController(initialPage: 1);

  final List<Widget> _children = [
    DeviceListScreen(),
    const HomeScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onTabTapped(int index) {
    if (index >= 0 && index < _children.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = AppThemeManager().colorSet;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _children,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.devices), // 기기: 여러 장비 느낌
            label: '기기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home), // HOME
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), // 설정: 톱니바퀴
            label: '설정',
          ),
        ],
      ),
    );
  }
}
