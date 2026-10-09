import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化(单一真源)。轻封装 SharedPreferences，全端通用(Web 用 localStorage)。
class LocalStorage {
  LocalStorage._(this._prefs);
  final SharedPreferences _prefs;

  static LocalStorage? _instance;
  static LocalStorage get instance {
    assert(_instance != null, 'LocalStorage 未初始化，请先 await LocalStorage.init()');
    return _instance!;
  }

  static Future<LocalStorage> init() async {
    _instance ??= LocalStorage._(await SharedPreferences.getInstance());
    return _instance!;
  }

  static const _kAuthToken = 'auth_token';
  static const _kThemeMode = 'theme_mode';
  static const _kPrimary = 'theme_primary';
  static const _kSecondary = 'theme_secondary';
  static const _kFontScale = 'theme_font_scale';
  static const _kTranscriptWidth = 'layout_transcript_width';
  static const _kTransparentMode = 'theme_transparent_mode';
  static const _kLocale = 'locale';
  static const _kUsername = 'user_profile_username';
  static const _kAvatar = 'user_profile_avatar';

  String? get authToken => _prefs.getString(_kAuthToken);
  Future<void> setAuthToken(String? v) async =>
      v == null ? _prefs.remove(_kAuthToken) : _prefs.setString(_kAuthToken, v);


  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  int? get primary => _prefs.getInt(_kPrimary);
  Future<void> setPrimary(int v) => _prefs.setInt(_kPrimary, v);

  int? get secondary => _prefs.getInt(_kSecondary);
  Future<void> setSecondary(int v) => _prefs.setInt(_kSecondary, v);

  double? get fontScale => _prefs.getDouble(_kFontScale);
  Future<void> setFontScale(double v) => _prefs.setDouble(_kFontScale, v);

  /// 中栏转录宽度档位（`narrow` / `medium` / `wide`）。null = 未设置过，
  /// 由 `TranscriptWidth.parse` 落到默认的 medium。
  String? get transcriptWidth => _prefs.getString(_kTranscriptWidth);
  Future<void> setTranscriptWidth(String v) =>
      _prefs.setString(_kTranscriptWidth, v);

  bool? get transparentMode => _prefs.getBool(_kTransparentMode);
  Future<void> setTransparentMode(bool v) => _prefs.setBool(_kTransparentMode, v);

  String? get locale => _prefs.getString(_kLocale);
  Future<void> setLocale(String? v) async =>
      v == null ? _prefs.remove(_kLocale) : _prefs.setString(_kLocale, v);

  String? get username => _prefs.getString(_kUsername);
  Future<void> setUsername(String? v) async =>
      v == null ? _prefs.remove(_kUsername) : _prefs.setString(_kUsername, v);

  String? get avatar => _prefs.getString(_kAvatar);
  Future<void> setAvatar(String? v) async =>
      v == null ? _prefs.remove(_kAvatar) : _prefs.setString(_kAvatar, v);
}
