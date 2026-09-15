// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidUrl => 'Please enter a valid URL';

  @override
  String get loginTitle => 'Login';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to logout?';

  @override
  String get logoutServerFailedWarning =>
      'Could not logout from server, but logged out locally';

  @override
  String get retry => 'Retry';

  @override
  String get ssoWebViewTitle => 'Sign In';

  @override
  String get ssoCancel => 'Cancel';

  @override
  String ssoSignInWith(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get ssoOrDivider => 'OR';

  @override
  String get next => 'Next';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Enter your username';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get mfaTitle => 'Two-Factor Authentication';

  @override
  String get mfaCode => 'MFA code';

  @override
  String get mfaCodeHint => 'Enter 6-digit code';

  @override
  String get mfaCodeRequired => 'Please enter MFA code';

  @override
  String get verify => 'Verify';

  @override
  String get mapTab => 'Map';

  @override
  String get activitiesTab => 'Activities';

  @override
  String get settingsTab => 'Settings';

  @override
  String get settingsScreen => 'Settings';

  @override
  String get serverSettings => 'Server';

  @override
  String get serverSettingsTitle => 'Server settings';

  @override
  String get loggedIn => 'Logged in';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://example.com';

  @override
  String get tileServerUrl => 'Map tile server URL';

  @override
  String get tileServerUrlHint => 'https://tile.openstreetmap.org/...';

  @override
  String get savedSuccessfully => 'Settings saved successfully';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRussian => 'Russian';

  @override
  String get activitiesTitle => 'Activities';

  @override
  String get activityDetailsTitle => 'Activity details';

  @override
  String get activityType => 'Type';

  @override
  String get activityDistance => 'Distance';

  @override
  String get activityDuration => 'Duration';

  @override
  String get activityPoints => 'GPS points';

  @override
  String get activityUploadStatus => 'Upload status';

  @override
  String get activityKindRunning => 'Running';

  @override
  String get activityKindCycling => 'Cycling';

  @override
  String get activityKindWalking => 'Walking';

  @override
  String get activityKindHiking => 'Hiking';

  @override
  String get activityKindWorkout => 'Workout';

  @override
  String get uploadStatusPending => 'Pending';

  @override
  String get uploadStatusUploaded => 'Uploaded';

  @override
  String get uploadStatusFailed => 'Failed';

  @override
  String get importGpx => 'Import GPX';

  @override
  String get importFailed => 'Import failed';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get activityUploaded => 'Activity uploaded';

  @override
  String get noActivitiesYet => 'No activities yet';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get upload => 'Upload';

  @override
  String get exportGpx => 'Export GPX';

  @override
  String get editActivityTitle => 'Edit activity';

  @override
  String get deleteActivityTitle => 'Delete activity';

  @override
  String get deleteActivityMessage => 'Delete activity';

  @override
  String get activityTitle => 'Title';

  @override
  String get activityNotes => 'Notes';

  @override
  String get trackingActive => 'Tracking:';

  @override
  String get trackerIdle => 'Tracker idle';

  @override
  String get averageSpeed => 'Average speed';

  @override
  String get cacheArea => 'Cache';

  @override
  String get selectArea => 'Select area';

  @override
  String get selectAreaEnabled => 'Area selected';

  @override
  String get cachedTiles => 'Cached tiles';

  @override
  String get cacheError => 'Cache error';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get startActivity => 'Start activity';

  @override
  String get stopActivity => 'Stop activity';

  @override
  String get stopActivityConfirm => 'Finish and save current activity?';

  @override
  String get myLocation => 'My location';

  @override
  String get settingsUpdated => 'Settings updated';

  @override
  String get bluetoothSensors => 'Bluetooth sensors';

  @override
  String get scan => 'Scan';

  @override
  String get savedDevices => 'Saved devices';

  @override
  String get noSavedSensors => 'No saved sensors';

  @override
  String get nearbyDevices => 'Nearby devices';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get add => 'Add';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get gpsTracking => 'GPS & Tracking';

  @override
  String get gpsAccuracyMode => 'Accuracy mode';

  @override
  String get gpsAccuracyHigh => 'High (GPS)';

  @override
  String get gpsAccuracyBalanced => 'Balanced (GPS + network)';

  @override
  String get gpsAccuracyLow => 'Low power';

  @override
  String get minDistanceBetweenPoints => 'Min distance between points';

  @override
  String get syncAndCache => 'Sync and cache';

  @override
  String get uploadEndpoint => 'Upload endpoint';

  @override
  String get apiPassword => 'API password';

  @override
  String get apiPasswordHint => 'Enter server-generated API password';

  @override
  String get mapCacheFolder => 'Map cache folder';

  @override
  String get saveTrackingSettings => 'Save tracking settings';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get tabRecord => 'Record';

  @override
  String get tabHistory => 'History';

  @override
  String get tabGear => 'Gear';

  @override
  String get profileTab => 'Profile';

  @override
  String get themeTab => 'Theme';

  @override
  String get mapSettingsTab => 'Map';

  @override
  String get coachTab => 'Coach';

  @override
  String get systemTab => 'System';

  @override
  String get profileAnonymous => 'Anonymous';

  @override
  String get profilePersonalData => 'Personal data';

  @override
  String get profileHeight => 'Height (cm)';

  @override
  String get profileWeight => 'Weight (kg)';

  @override
  String get profileCity => 'City';

  @override
  String get profileMaxHr => 'Max HR';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileMale => 'Male';

  @override
  String get profileFemale => 'Female';

  @override
  String get profileNA => 'N/A';

  @override
  String get profileLoading => 'Loading...';

  @override
  String get profileRefresh => 'Refresh from server';

  @override
  String get dynamicColor => 'Dynamic Color (Android 12+)';

  @override
  String get accentColor => 'Accent color';

  @override
  String get pickColor => 'Pick color';

  @override
  String get bgColor => 'Background color';

  @override
  String get enableGradient => 'Enable gradient';

  @override
  String get gradientColor => 'Gradient color';

  @override
  String get topographicMap => 'Topographic map';

  @override
  String get mapTheme => 'Map theme';

  @override
  String get mapThemeAuto => 'Auto';

  @override
  String get mapThemeLight => 'Light';

  @override
  String get mapThemeDark => 'Dark';

  @override
  String get matchSystemTheme => 'Match system theme';

  @override
  String get mapBehavior => 'Map behavior while tracking';

  @override
  String get mapBehaviorDesc =>
      'Controls how the map responds to your movement during a tracking session.';

  @override
  String get mapBehaviorOff => 'Disabled';

  @override
  String get mapBehaviorOffDesc => 'Map stays in place';

  @override
  String get mapBehaviorFollow => 'Follow location';

  @override
  String get mapBehaviorFollowDesc => 'Center on GPS position';

  @override
  String get mapBehaviorFollowHeading => 'Follow + heading';

  @override
  String get mapBehaviorFollowHeadingDesc => 'Rotate map with compass';

  @override
  String get gpsAccuracy => 'Accuracy';

  @override
  String get distanceFilter => 'Distance filter (m)';

  @override
  String get meters => 'meters';

  @override
  String get mapCache => 'Map cache';

  @override
  String get cacheFolder => 'Cache folder';

  @override
  String get voiceCoach => 'Voice coach';

  @override
  String get voiceGender => 'Voice gender';

  @override
  String get speechRate => 'Speech rate';

  @override
  String get volume => 'Volume';

  @override
  String get twoFactorAuth => 'Two-factor auth (MFA)';

  @override
  String get mfaSecretHelper => 'TOTP secret key for two-factor authentication';

  @override
  String get mfaSecretDesc =>
      'If you have 2FA enabled on your account, save the TOTP secret (from the authenticator app) here so the app can generate verification codes automatically.';

  @override
  String get dataUpload => 'Data upload';

  @override
  String get clearLocalCache => 'Clear local cache';

  @override
  String get clearCacheTitle => 'Clear cache?';

  @override
  String get clearCacheMsg =>
      'This will remove all locally stored activity and fitness data.';

  @override
  String get clear => 'Clear';

  @override
  String get searchHint => 'Search by name...';

  @override
  String get allTypes => 'All types';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get inCloud => 'In cloud';

  @override
  String get pendingUpload => 'Pending upload';

  @override
  String get uploadError => 'Upload error';

  @override
  String get sessionExpired =>
      'Session expired. Please log in again — fields are pre-filled.';

  @override
  String get serverError => 'Server error';

  @override
  String get profileUpdateFailed => 'Failed to update profile';

  @override
  String get healthTab => 'Health';

  @override
  String get healthSummary => 'Summary';

  @override
  String get healthWeight => 'Weight';

  @override
  String get healthSleep => 'Sleep';

  @override
  String get healthWater => 'Water';

  @override
  String get healthSteps => 'Steps';

  @override
  String get todaySummary => 'Today\'s summary';

  @override
  String get noData => 'No data';

  @override
  String get quality => 'Quality';

  @override
  String get goal => 'Goal';

  @override
  String get todayDrunk => 'Drunk today';

  @override
  String get history => 'History';

  @override
  String get noWaterRecords => 'No water records';

  @override
  String get glass => 'Glass';

  @override
  String get bottle => 'Bottle';

  @override
  String get editVolume => 'Edit volume (ml)';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get deleteRecordConfirm => 'This action cannot be undone.';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get weeklyStats => 'Weekly stats';

  @override
  String get editSteps => 'Edit steps';

  @override
  String get stepsHistory => 'Steps history';

  @override
  String get noSleepRecords => 'No sleep records';

  @override
  String get noWeightRecords => 'No weight records';

  @override
  String get addWeight => 'Add weight';

  @override
  String get addSleep => 'Add sleep';

  @override
  String get bedtime => 'Bedtime';

  @override
  String get wakeTime => 'Wake time';

  @override
  String get totalSleep => 'Total sleep';

  @override
  String get sleepQuality => 'Sleep quality';

  @override
  String get feedMyFeed => 'My feed';

  @override
  String get feedSubscriptions => 'Subscriptions';

  @override
  String get feedEmptyMy => 'No activities in cloud yet';

  @override
  String get feedEmptyFriends => 'Friends feed is empty';

  @override
  String get activityMoving => 'Moving time';

  @override
  String get activityMaxSpeed => 'Max speed';

  @override
  String get activityAvgSpeed => 'Avg speed';

  @override
  String get activityElevation => 'Elevation gain';

  @override
  String get activityNoNotes => 'No notes';

  @override
  String get activityAddPhoto => 'Add photo';

  @override
  String get activityDeleteTitle => 'Delete activity?';

  @override
  String get activityDeleteMsg => 'This action cannot be undone.';

  @override
  String get activityTryAgain => 'Try again';

  @override
  String get activityDisplayError => 'Display error';

  @override
  String get activityCouldNotDisplay => 'Could not display activity:';

  @override
  String get activityCharts => 'Charts';

  @override
  String get activitySpeed => 'Speed';

  @override
  String get activityAltitude => 'Altitude';

  @override
  String get activitySplit => 'Split';

  @override
  String get activitySplitPace => 'Pace';

  @override
  String get activitySplitElev => 'Elevation';

  @override
  String get activityPR => 'Personal record';

  @override
  String get activityPRBadge => 'New PR!';

  @override
  String get gearNotFound => 'No gear found';

  @override
  String get gearPrimary => 'PRIMARY';

  @override
  String get gearMakePrimary => 'Set as primary for:';

  @override
  String get gearDefaultCats => 'No default categories for this gear type';

  @override
  String get gearClose => 'Close';

  @override
  String get gearTotalKm => 'Total distance';

  @override
  String get gearPurchaseCost => 'Purchase cost';

  @override
  String get gearPartsCost => 'Parts cost';

  @override
  String get notifSyncComplete => 'Sync complete';

  @override
  String get notifSync => 'Sync';

  @override
  String get notifSyncStatus => 'Sync status';

  @override
  String get settingsStatsDisplay => 'Stats display';

  @override
  String get settingsStatsRings => 'Ring indicators';

  @override
  String get settingsStatsCards => 'Card grid';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginOr => 'or';

  @override
  String get loginWithSSO => 'Sign in with SSO';

  @override
  String get trackingDistance => 'Distance';

  @override
  String get trackingDuration => 'Duration';

  @override
  String get trackingCurrentSpeed => 'Speed';

  @override
  String get trackingElevationGain => 'Elevation';

  @override
  String get healthHeartRate => 'Heart Rate';

  @override
  String get importFromHealthConnect => 'Import from Health Connect';

  @override
  String importSummary(Object count) {
    return 'Imported: $count records';
  }

  @override
  String get hrZoneRest => 'Rest';

  @override
  String get hrZoneFatBurn => 'Fat Burn';

  @override
  String get hrZoneCardio => 'Cardio';

  @override
  String get hrZonePeak => 'Peak';

  @override
  String get importing => 'Importing...';

  @override
  String get noHeartRateRecords => 'No heart rate records';

  @override
  String get healthConnectNotAvailable =>
      'Health Connect is not available on this device';
}
