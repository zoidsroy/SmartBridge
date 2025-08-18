// Mood: Conservative (Light mode)
// Font: poppins
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// App Theme
class AppThemeManager {
  late final ColorSet colorSet;
  late final TextTheme textTheme;
  late final Components components;

  static final AppThemeManager _instance = AppThemeManager._internal();

  AppThemeManager._internal();

  factory AppThemeManager() {
    return _instance;
  }

  static Future<void> initialize() async {
    final jsonString =
    await rootBundle.loadString('assets/light_conservative_colorset.json');
    final jsonData = json.decode(jsonString);

    _instance.colorSet = ColorSet.fromMap(jsonData);
    _instance.textTheme = CustomTextStyle.textTheme;
    _instance.components = Components(
      colorSet: _instance.colorSet,
      customTextTheme: _instance.textTheme,
    );
  }

  // factory AppThemeManager.light() {
  //   return AppThemeManager(
  //     colorSet: colors,
  //     textTheme: textTheme,
  //     components: components,
  //   );
  // }

  // factory AppThemeManager.dark() {
  //   final colors = ColorSet();
  //   final textTheme = CustomTextStyle.textTheme;
  //   final components = Components(
  //     colorSet: colors,
  //     customTextTheme: textTheme,
  //   );

  //   return AppThemeManager(
  //     colorSet: colors,
  //     textTheme: textTheme,
  //     components: components,
  //   );
  // }

  ThemeData get theme => ThemeData(
    ///
    colorScheme: colorSet.light(),
    textTheme: CustomTextStyle.textTheme,
    bottomAppBarTheme: components.bottomAppBarTheme,
    appBarTheme: components.appBarTheme,
    badgeTheme: components.badgeThemeData,
    filledButtonTheme: components.filledButtonThemeData,
    elevatedButtonTheme: components.elevatedButtonThemeData,
    outlinedButtonTheme: components.outlinedButtonThemeData,
    textButtonTheme: components.textButtonThemeData,
    floatingActionButtonTheme: components.floatingActionButtonThemeData,
    iconButtonTheme: components.iconButtonThemeData,
    segmentedButtonTheme: components.segmentedButtonThemeData,
    cardTheme: components.cardTheme,
    checkboxTheme: components.checkboxThemeData,
    chipTheme: components.chipTheme,
    dialogTheme: components.dialogTheme,
    dividerTheme: components.dividerThemeData,
    listTileTheme: components.listTileThemeData,
    bottomNavigationBarTheme: components.bottomNavigationBarThemeData,
    progressIndicatorTheme: components.progressIndicatorThemeData,
    radioTheme: components.radioThemeData,
    bottomSheetTheme: components.bottomSheetThemeData,
    snackBarTheme: components.snackBarThemeData,
    tabBarTheme: components.tabBarTheme,
    inputDecorationTheme: components.inputDecorationTheme,
    scaffoldBackgroundColor: colorSet.white,
    canvasColor: colorSet.white,
    cardColor: colorSet.greyishWhite,
    // Duplicated with cardTheme
    dialogBackgroundColor: colorSet.white,
    // Duplicated with dialogTheme
    dividerColor: colorSet.grey,
    // Duplicated with dividerTheme
    indicatorColor: colorSet.primaryAccent,

    // Need Implementation
    actionIconTheme: null,
    adaptations: null,
    applyElevationOverlayColor: null,
    bannerTheme: null,
    buttonTheme: null,
    cupertinoOverrideTheme: null,
    // IOS Style
    dataTableTheme: null,
    datePickerTheme: null,
    disabledColor: null,
    drawerTheme: null,
    dropdownMenuTheme: null,
    expansionTileTheme: null,
    extensions: null,
    // Generate Theme Extension
    focusColor: null,
    fontFamily: null,
    fontFamilyFallback: null,
    highlightColor: null,
    hintColor: null,
    hoverColor: null,
    iconTheme: null,
    materialTapTargetSize: null,
    menuBarTheme: null,
    menuButtonTheme: null,
    menuTheme: null,
    navigationBarTheme: null,
    navigationDrawerTheme: null,
    navigationRailTheme: null,
    package: null,
    pageTransitionsTheme: null,
    platform: null,
    popupMenuTheme: null,
    primaryColor: colorSet.primary,
    primaryColorDark: null,
    primaryColorLight: null,
    primaryIconTheme: null,
    primarySwatch: null,
    primaryTextTheme: null,
    scrollbarTheme: null,
    searchBarTheme: null,
    searchViewTheme: null,
    secondaryHeaderColor: null,
    shadowColor: null,
    sliderTheme: null,
    splashColor: null,
    splashFactory: null,
    switchTheme: null,
    textSelectionTheme: null,
    timePickerTheme: null,
    toggleButtonsTheme: null,
    tooltipTheme: null,
    typography: null,
    unselectedWidgetColor: null,
    visualDensity: null,

    // Default Value
    colorSchemeSeed: null,
    useMaterial3: true,
  );
}

/// ColorSet
class ColorSet {
  ///change hsl code to color
  static Color hslToColor(int h, int s, int l) {
    return HSLColor.fromAHSL(1, h.toDouble(), s / 100, l / 100).toColor();
  }

  /// Palette colors from keyColor.json
  /// These colors will be loaded from JSON
  final Color primary;
  final Color primaryAccent;
  final Color secondary;
  final Color white;
  final Color greyishWhite;
  final Color black;
  final Color grey;
  final Color lightGrey;
  final Color whiteGrey;
  final Color error;

  // ... other palette colors

  ColorSet({
    required this.primary,
    required this.primaryAccent,
    required this.secondary,
    required this.white,
    required this.greyishWhite,
    required this.black,
    required this.grey,
    required this.lightGrey,
    required this.whiteGrey,
    required this.error,
  });

  factory ColorSet.fromMap(Map<String, dynamic> map) {
    return ColorSet(
      primary: fromJsonToHSLColor(map['primary']).toColor(),
      primaryAccent: fromJsonToHSLColor(map['primaryAccent']).toColor(),
      secondary: fromJsonToHSLColor(map['secondary']).toColor(),
      white: fromJsonToHSLColor(map['white']).toColor(),
      greyishWhite: fromJsonToHSLColor(map['greyishWhite']).toColor(),
      black: fromJsonToHSLColor(map['black']).toColor(),
      grey: fromJsonToHSLColor(map['grey']).toColor(),
      lightGrey: fromJsonToHSLColor(map['lightGrey']).toColor(),
      whiteGrey: fromJsonToHSLColor(map['whiteGrey']).toColor(),
      error: fromJsonToHSLColor(map['error']).toColor(),
    );
  }

  static HSLColor fromJsonToHSLColor(Map<String, dynamic> map) {
    return HSLColor.fromAHSL(
      1,
      map['hue'].toDouble(),
      map['saturation'].toDouble() / 100,
      map['lightness'].toDouble() / 100,
    );
  }

  /// you should add this in main.dart initialize part
  /// For example, add line in main function
  ///
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   ** await ColorSet.initialize(); **
  ///   await Firebase.initializeApp(
  ///     options: DefaultFirebaseOptions.currentPlatform,
  ///  );
  ///
  ///   bool permissionsGranted = await PermissionHelper.requestRequiredPermissions();
  ///
  ///   runApp(const MyApp());
  /// }
  ///
  /// @search-color-set
  ColorScheme light() {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.light,
      // ... customize other colors
    );
  }

  ColorScheme dark() {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.dark,
      // ... customize other colors
    );
  }
}

// Components
class Components {
  final ColorSet colorSet;
  final TextTheme customTextTheme;

  Components({
    required this.colorSet,
    required this.customTextTheme,
  });

  BottomAppBarTheme get bottomAppBarTheme => BottomAppBarTheme(
    color: colorSet.greyishWhite,
  );

  /// @search-app-bar
  AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: colorSet.whiteGrey,
    foregroundColor: colorSet.black,
    centerTitle: true,
    toolbarHeight: 64,
    titleTextStyle: CustomTextStyle.appBarFont,
  );

  BadgeThemeData get badgeThemeData => BadgeThemeData(
    backgroundColor: colorSet.primary,
    textColor: colorSet.white,
    alignment: Alignment.center,
  );

  FilledButtonThemeData get filledButtonThemeData => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: colorSet.primary,
      foregroundColor: colorSet.greyishWhite,
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 24, right: 24),
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      ),
      textStyle: CustomTextStyle.buttonFont,
    ),
  );

  ElevatedButtonThemeData get elevatedButtonThemeData =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          // 사실상 FilledButton2 역할로 사용됨
          backgroundColor: colorSet.primaryAccent,
          foregroundColor: colorSet.black,
          padding: const EdgeInsets.only(top: 8, bottom: 10, left: 24, right: 24),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius.md),
          ),
          textStyle: CustomTextStyle.buttonFont,
        ),
      );

  OutlinedButtonThemeData get outlinedButtonThemeData =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorSet.primary),
          foregroundColor: colorSet.black,
          backgroundColor: colorSet.white,
          padding: const EdgeInsets.only(top: 8, bottom: 10, left: 24, right: 24),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius.md),
          ),
          textStyle: CustomTextStyle.buttonFont,
        ),
      );

  TextButtonThemeData get textButtonThemeData => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: colorSet.black,
      textStyle: CustomTextStyle.textButtonFont.copyWith(
        decoration: TextDecoration.underline,
      ),
    ),
  );

  FloatingActionButtonThemeData get floatingActionButtonThemeData =>
      FloatingActionButtonThemeData(
        backgroundColor: colorSet.primary,
        foregroundColor: colorSet.white,
      );

  IconButtonThemeData get iconButtonThemeData => IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: colorSet.grey,
      // backgroundColor: colorSet.primary,
      // 패스워드 입력 필드에 사용하는 눈 아이콘 때문에 백그라운드 지정 안 함
    ),
  );

  SegmentedButtonThemeData get segmentedButtonThemeData =>
      SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: colorSet.greyishWhite,
          foregroundColor: colorSet.grey,
          selectedBackgroundColor: colorSet.primary,
          selectedForegroundColor: colorSet.white,
        ),
      );

  CardThemeData get cardTheme => CardThemeData(
    elevation: 0,
    color: colorSet.greyishWhite,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
    ),
  );

  CheckboxThemeData get checkboxThemeData => CheckboxThemeData(
    side: BorderSide(color: colorSet.lightGrey),
    checkColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return colorSet.grey; // 선택 불가능한 항목의 체크 아이콘 컬러
        }
        if (states.contains(WidgetState.selected)) {
          return colorSet.white; // 선택된 항목의 체크 아이콘 컬러
        }
        return colorSet.white; // 선택되지 않은 항목의 체크 아이콘 컬러
      },
    ),
    fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return colorSet.lightGrey; // 선택 불가능한 항목의 배경 컬러
        }
        if (states.contains(WidgetState.selected)) {
          return colorSet.secondary; // 선택된 항목의 배경 컬러
        }
        return colorSet.greyishWhite; // 선택되지 않은 항목의 배경 컬러
      },
    ),
  );

  ChipThemeData get chipTheme => ChipThemeData(
      color: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorSet.lightGrey; // 선택 불가능한 항목의 배경 컬러
          }
          if (states.contains(WidgetState.selected)) {
            return colorSet.primary; // 선택된 항목의 배경 컬러
          }
          return colorSet.whiteGrey; // 선택되지 않은 항목의 배경 컬러
        },
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      ),
      side: BorderSide.none,
      labelStyle: TextStyle(
        // 텍스트 컬러
        color: colorSet.black,
      ));

  DialogThemeData get dialogTheme => DialogThemeData(
    elevation: 0,
    backgroundColor: colorSet.white,
    iconColor: colorSet.primary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
    ),
    titleTextStyle: CustomTextStyle.dialogFont,
    contentTextStyle: CustomTextStyle.inputFieldFont,
  );

  DividerThemeData get dividerThemeData => DividerThemeData(
    color: colorSet.whiteGrey,
  );

  ListTileThemeData get listTileThemeData => ListTileThemeData(
    titleTextStyle: CustomTextStyle.listTileTitleFont,
    subtitleTextStyle: CustomTextStyle.listTileSubtitleFont,
    contentPadding: EdgeInsets.symmetric(
      horizontal: DesignTokens.spacing.xl,
      vertical: DesignTokens.spacing.xs,
    ),
  );

  BottomNavigationBarThemeData get bottomNavigationBarThemeData =>
      BottomNavigationBarThemeData(
        selectedItemColor: colorSet.primary,
        unselectedItemColor: colorSet.lightGrey,
        backgroundColor: colorSet.white,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 8,
      );

  ProgressIndicatorThemeData get progressIndicatorThemeData =>
      ProgressIndicatorThemeData(
        circularTrackColor: colorSet.primary,
        linearTrackColor: colorSet.primary,
        color: colorSet.primary,
      );

  RadioThemeData get radioThemeData => RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return colorSet.whiteGrey;
        }
        if (states.contains(WidgetState.selected)) {
          return colorSet.primary;
        }
        return colorSet.lightGrey;
      },
    ),
  );

  BottomSheetThemeData get bottomSheetThemeData => BottomSheetThemeData(
    backgroundColor: colorSet.white,
    dragHandleColor: colorSet.grey,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
    ),
  );

  SnackBarThemeData get snackBarThemeData => SnackBarThemeData(
    backgroundColor: colorSet.black,
    actionTextColor: colorSet.primary,
    closeIconColor: colorSet.grey,
    elevation: 0,
  );

  TabBarThemeData get tabBarTheme => TabBarThemeData(
      labelColor: colorSet.black,
      unselectedLabelColor: colorSet.lightGrey,
      dividerColor: colorSet.whiteGrey,
      indicatorColor: colorSet.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: CustomTextStyle.listTileTitleFont,
      unselectedLabelStyle: CustomTextStyle.listTileTitleFont.copyWith(
        color: AppThemeManager().colorSet.lightGrey,
      ));

  InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      borderSide: BorderSide(
        color: colorSet.lightGrey,
        width: 1, // 테두리 두께
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      borderSide: BorderSide(
        color: colorSet.lightGrey,
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      borderSide: BorderSide(
        color: colorSet.primaryAccent, // 활성 상태일 때 테두리 색상
        width: 1, // 테두리 두께
      ),
    ),
    errorStyle: CustomTextStyle.errorFont,
    errorBorder: OutlineInputBorder(
      // 에러 상태일 때의 테두리
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      borderSide: BorderSide(
        color: colorSet.error,
        width: 1,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      // 에러 상태에서 포커스됐을 때의 테두리
      borderRadius: BorderRadius.circular(DesignTokens.radius.md),
      borderSide: BorderSide(
        color: colorSet.error,
        width: 1,
      ),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: DesignTokens.spacing.xl,
      vertical: DesignTokens.spacing.lg,
    ),
    hintStyle: CustomTextStyle.inputHintFont,
    labelStyle: CustomTextStyle.inputLabelFont,
    counterStyle: CustomTextStyle.inputCounterFont,
    iconColor: colorSet.lightGrey,
  );

// ------

// /// @search-outline-input
// InputDecorationTheme get outlineInput => InputDecorationTheme(
//       border: OutlineInputBorder(
//         borderRadius: DesignTokens.radius.sm,
//         borderSide: BorderSide(color: colorSet.outline),
//       ),
//       contentPadding: EdgeInsets.all(DesignTokens.spacing.md),
//       filled: true,
//       fillColor: colorSet.surface,
//       prefixIconColor: colorSet.onSurfaceVariant,
//       suffixIconColor: colorSet.onSurfaceVariant,
//     );

// /// make your own components here

// /// @search-underline-input
// InputDecorationTheme get underlineInput => InputDecorationTheme(
//       border: UnderlineInputBorder(
//         borderSide: BorderSide(color: colorSet.outline),
//       ),
//       contentPadding: EdgeInsets.symmetric(
//         vertical: DesignTokens.spacing.sm,
//         horizontal: DesignTokens.spacing.md,
//       ),
//     );

// /// @search-elevated-button
// ElevatedButtonThemeData get elevatedButton => ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: colorSet.primary,
//         foregroundColor: colorSet.onPrimary,
//         padding: EdgeInsets.symmetric(
//           horizontal: DesignTokens.spacing.lg,
//           vertical: DesignTokens.spacing.md,
//         ),
//         shape: RoundedRectangleBorder(
//           borderRadius: DesignTokens.radius.sm,
//         ),
//         elevation: DesignTokens.elevation.sm,
//       ),
//     );

/// @search-text-button
// TextButtonThemeData get textButton =>
//     TextButtonThemeData(
//       style: TextButton.styleFrom(
//         foregroundColor: colorSet.black,
//         padding: EdgeInsets.symmetric(
//           horizontal: DesignTokens.spacing.md,
//           vertical: DesignTokens.spacing.sm,
//         ),
//         textStyle: CustomTextStyle.textButtonFont,
//       ),
//     );
//
}

// Font Style
class CustomTextStyle {
  /// create your own font style
  /// @search-text-theme
  static TextTheme get textTheme => TextTheme(
    // Display
    displayLarge: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.displayLarge,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.displayMedium,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.displaySmall,
    ),
    // Headline
    headlineLarge: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.headlineLarge,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.headlineMedium,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.headlineSmall,
    ),
    // Title
    titleLarge: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.titleLarge,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.titleMedium,
    ),
    titleSmall: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.titleSmall,
    ),
    // Body
    bodyLarge: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.bodyLarge,
      letterSpacing: -0.5,
    ),
    bodyMedium: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.bodyMedium,
      letterSpacing: -0.5,
    ),
    bodySmall: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.bodySmall,
      letterSpacing: -0.5,
    ),
    // Label
    labelLarge: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.labelLarge,
    ),
    labelMedium: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.labelMedium,
    ),
    labelSmall: GoogleFonts.poppins(
      fontSize: DesignTokens.fontSize.labelSmall,
    ),
  );

  /// appBar font style
  /// 이 getter들은 Components나 다른 곳에서 직접 사용할 때 필요
  /// @search-custom-text-style

  // AppBar 텍스트 설정
  static TextStyle get appBarFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.titleMedium,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppThemeManager().colorSet.black,
  );

  // Sign In Welcome
  static TextStyle get welcomeFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.headlineMedium,
    fontWeight: FontWeight.w500,
    color: AppThemeManager().colorSet.black,
    letterSpacing: -0.5,
  );

  static TextStyle get normalFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.bodyMedium,
    fontWeight: FontWeight.w300,
    color: AppThemeManager().colorSet.black,
  );

  // 바디 안에 들어가는 타이틀
  static TextStyle get accentFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.titleSmall,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppThemeManager().colorSet.black,
  );

  // FilledButton, ElevatedButton, OutlinedButton 텍스트 설정
  static TextStyle get buttonFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.bodyLarge,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  // TextButton 텍스트 설정
  static TextStyle get textButtonFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelLarge,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // Dialog Title 텍스트 설정
  static TextStyle get dialogFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.bodyLarge,
    fontWeight: FontWeight.w500,
    color: AppThemeManager().colorSet.black,
  );

  // listTile Title 텍스트 설정
  static TextStyle get listTileTitleFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelMedium,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppThemeManager().colorSet.black,
  );

  // listTile Subtitle 텍스트 설정
  static TextStyle get listTileSubtitleFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelSmall,
    fontWeight: FontWeight.w300,
    letterSpacing: 0,
    color: AppThemeManager().colorSet.black,
  );

  // Input Label 텍스트 설정
  static TextStyle get inputLabelFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelLarge,
    fontWeight: FontWeight.w500,
    color: AppThemeManager().colorSet.secondary,
    letterSpacing: 0,
  );

  // Input Field 텍스트 설정
  static TextStyle get inputFieldFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelMedium,
    fontWeight: FontWeight.w400,
    color: AppThemeManager().colorSet.black,
    letterSpacing: 0,
  );

  // Input Hint 텍스트 설정
  static TextStyle get inputHintFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelMedium,
    fontWeight: FontWeight.w400,
    color: AppThemeManager().colorSet.grey,
    letterSpacing: 0,
  );

  // Input Counter 텍스트 설정
  static TextStyle get inputCounterFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelSmall,
    fontWeight: FontWeight.w400,
    color: AppThemeManager().colorSet.grey,
    letterSpacing: 0.5,
  );

  // Error 텍스트 설정
  static TextStyle get errorFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.labelSmall,
    fontWeight: FontWeight.w400,
    color: AppThemeManager().colorSet.error,
    letterSpacing: 0,
  );

  // terms Agreement 텍스트 설정
  static TextStyle get policyFont => GoogleFonts.poppins(
    fontSize: DesignTokens.fontSize.captionLarge,
    fontWeight: FontWeight.w400,
    color: AppThemeManager().colorSet.black,
    letterSpacing: -0.5,
  );
}

class FontSet {
  /// set your own font style
  /// example: pointFont = GoogleFonts.bebasNeue(fontWeight: FontWeight.w300);
  /// @search-font-set
  // poppins Weights
  static final poppinsLight = GoogleFonts.poppins(fontWeight: FontWeight.w200);
  static final poppinsRegular =
  GoogleFonts.poppins(fontWeight: FontWeight.w300);
  static final poppinsMedium = GoogleFonts.poppins(fontWeight: FontWeight.w400);
  static final poppinsSemiBold =
  GoogleFonts.poppins(fontWeight: FontWeight.w500);
  static final poppinsBold = GoogleFonts.poppins(fontWeight: FontWeight.w600);
}

// Design Tokens
class DesignTokens {
  /// design tokens are unchanged values
  /// static const ensure only one instance
  /// don't need to initialize at runtime
  /// don't need to allocate memory for each instance
  static const spacing = Spacing();
  static final radius = _Radius();
  static const animation = _Animation();
  static const elevation = Elevation();
  static const fontSize = FontSize();
  static const opacity = Opacity();
  static const iconSize = IconSize();
  static const breakpoint = BreakPoint();
}

class Spacing {
  const Spacing();

  // todo: adjust spacing values and naming
  final double none = 0.0;
  final double xs = 4.0;
  final double sm = 8.0;
  final double md = 12.0;
  final double lg = 16.0;
  final double xl = 20.0;
  final double xxl = 24.0;
  final double xxxl = 32.0;
  final double xxxxl = 40.0;
  final double xxxxxl = 48.0;
  final double xxxxxxl = 56.0;
}

class _Radius {
  _Radius();

  // todo: adjust radius values and naming
  final double none = 0.0;
  final double xs = 4.0;
  final double sm = 8.0;
  final double md = 12.0;
  final double lg = 16.0;
  final double xl = 20.0;
  final double xxl = 24.0;
  final double xxxl = 32.0;
  final double xxxxl = 40.0;
  final double xxxxxl = 48.0;
  final double xxxxxxl = 64.0;
}

class _Animation {
  const _Animation();

  // todo: adjust animation values and naming
  final Duration shortest = const Duration(milliseconds: 100);
  final Duration short = const Duration(milliseconds: 300);
  final Duration medium = const Duration(milliseconds: 500);
  final Duration long = const Duration(milliseconds: 700);
  final Duration longest = const Duration(milliseconds: 1000);
}

class Elevation {
  /// elevation is for shadow
  const Elevation();

  final double none = 0.0;
  final double low = 1.0;
  final double medium = 4.0;
  final double high = 8.0;
  final double highest = 16.0;
}

class FontSize {
  const FontSize();

  // todo: adjust font size values and naming

  /// Headline sizes
  final double displayLarge = 40.0;
  final double displayMedium = 36.0;
  final double displaySmall = 32.0;

  /// Headline sizes
  final double headlineLarge = 32.0;
  final double headlineMedium = 28.0;
  final double headlineSmall = 24.0;

  /// Title sizes
  final double titleLarge = 22.0;
  final double titleMedium = 20.0;
  final double titleSmall = 18.0;

  /// Body sizes
  final double bodyLarge = 18.0;
  final double bodyMedium = 16.0;
  final double bodySmall = 14.0; // not recommended

  /// Caption sizes
  final double captionLarge = 12.0;
  final double captionMedium = 10.0;
  final double captionSmall = 8.0; // not recommended

  /// Label sizes
  final double labelLarge = 16.0;
  final double labelMedium = 14.0;
  final double labelSmall = 12.0; // not recommended
}

class Opacity {
  const Opacity();

  // todo: adjust opacity values and naming
  final double disabled = 0.38;
  final double subtle = 0.6;
  final double medium = 0.74;
  final double emphasis = 0.87;
  final double high = 1.0;
}

class IconSize {
  const IconSize();

  // todo: icon size depends on text size??
  final double xs = 16.0;
  final double sm = 20.0;
  final double md = 24.0;
  final double lg = 32.0;
  final double xl = 40.0;

// // 폰트 크기에 비례하는 아이콘 크기
// double get xs => FontSize.bodySmall * 1.2; // 12 * 1.2 = 14.4
// double get sm => FontSize.bodyMedium * 1.2; // 14 * 1.2 = 16.8
// double get md => FontSize.bodyLarge * 1.3; // 16 * 1.3 = 20.8
// double get lg => FontSize.titleMedium * 1.4; // 18 * 1.4 = 25.2
// double get xl => FontSize.titleLarge * 1.5; // 20 * 1.5 = 30.0

// // 특수 목적의 아이콘 크기
// double get button => FontSize.bodyMedium * 1.2; // 버튼용
// double get input => FontSize.bodyMedium * 1.15; // 입력필드용
// double get navigation => FontSize.titleSmall * 1.25; // 네비게이션용
}

class BreakPoint {
  const BreakPoint();

  // Minimum width of the screen
  final double mobile = 360.0;
  final double tablet = 768.0;
  final double desktop = 1024.0;
  final double wide = 1440.0;
}

// extension FilledButtonExtension on FilledButton {
//   FilledButton sub({
//     key,
//     required onPressed,
//     onLongPress,
//     onHover,
//     onFocusChange,
//     style,
//     focusNode,
//     autofocus,
//     clipBehavior,
//     statesController,
//     required child,
//   }) {
//     ColorSet colorSet = AppThemeManager().colorSet;

//     ButtonStyle buttonStyle = FilledButton.styleFrom(
//       backgroundColor: colorSet.black,
//       foregroundColor: colorSet.primary,
//     );

//     return FilledButton(
//       key: key,
//       onPressed: onPressed,
//       onLongPress: onLongPress,
//       onHover: onHover,
//       onFocusChange: onFocusChange,
//       style: buttonStyle.merge(style),
//       focusNode: focusNode,
//       autofocus: autofocus,
//       clipBehavior: clipBehavior,
//       statesController: statesController,
//       child: child,
//     );
//   }
// }