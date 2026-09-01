// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navDashboard => 'Overview';

  @override
  String get navUsers => 'Users';

  @override
  String get navOrganizations => 'Organizations';

  @override
  String get navPermissions => 'Permissions';

  @override
  String get navModels => 'Model Relay';

  @override
  String get navApiKeys => 'API Keys';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLogout => 'Log out';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginIdentifierPlaceholder => 'Enter your username';

  @override
  String get loginPasswordPlaceholder => 'Enter your password';

  @override
  String get loginCaptchaPlaceholder => 'Enter the code';

  @override
  String get loginCaptchaRefresh => 'Click to refresh the captcha';

  @override
  String get loginCaptchaFailed =>
      'Failed to load the captcha — click the image to retry';

  @override
  String get loginIdentifierRequired => 'Please enter your username';

  @override
  String get loginPasswordRequired => 'Please enter your password';

  @override
  String get loginCaptchaRequired => 'Please enter the image captcha';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsPrimaryColor => 'Primary color';

  @override
  String get settingsSecondaryColor => 'Secondary color';

  @override
  String get settingsFontScale => 'Font scale';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => 'No data';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonComingSoon => 'Coming soon';
}
