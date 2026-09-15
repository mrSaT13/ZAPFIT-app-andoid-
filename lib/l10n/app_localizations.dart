import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get invalidUrl;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmMessage;

  /// No description provided for @logoutServerFailedWarning.
  ///
  /// In en, this message translates to:
  /// **'Could not logout from server, but logged out locally'**
  String get logoutServerFailedWarning;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ssoWebViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get ssoWebViewTitle;

  /// No description provided for @ssoCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ssoCancel;

  /// No description provided for @ssoSignInWith.
  ///
  /// In en, this message translates to:
  /// **'Sign in with {provider}'**
  String ssoSignInWith(String provider);

  /// No description provided for @ssoOrDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get ssoOrDivider;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get usernameHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get mfaTitle;

  /// No description provided for @mfaCode.
  ///
  /// In en, this message translates to:
  /// **'MFA code'**
  String get mfaCode;

  /// No description provided for @mfaCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get mfaCodeHint;

  /// No description provided for @mfaCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter MFA code'**
  String get mfaCodeRequired;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @mapTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// No description provided for @activitiesTab.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activitiesTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @settingsScreen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreen;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSettings;

  /// No description provided for @serverSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get serverSettingsTitle;

  /// No description provided for @loggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get loggedIn;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get serverUrlHint;

  /// No description provided for @tileServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Map tile server URL'**
  String get tileServerUrl;

  /// No description provided for @tileServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://tile.openstreetmap.org/...'**
  String get tileServerUrlHint;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get savedSuccessfully;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @activitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activitiesTitle;

  /// No description provided for @activityDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity details'**
  String get activityDetailsTitle;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get activityType;

  /// No description provided for @activityDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get activityDistance;

  /// No description provided for @activityDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get activityDuration;

  /// No description provided for @activityPoints.
  ///
  /// In en, this message translates to:
  /// **'GPS points'**
  String get activityPoints;

  /// No description provided for @activityUploadStatus.
  ///
  /// In en, this message translates to:
  /// **'Upload status'**
  String get activityUploadStatus;

  /// No description provided for @activityKindRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get activityKindRunning;

  /// No description provided for @activityKindCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get activityKindCycling;

  /// No description provided for @activityKindWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get activityKindWalking;

  /// No description provided for @activityKindHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get activityKindHiking;

  /// No description provided for @activityKindWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get activityKindWorkout;

  /// No description provided for @uploadStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get uploadStatusPending;

  /// No description provided for @uploadStatusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploadStatusUploaded;

  /// No description provided for @uploadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get uploadStatusFailed;

  /// No description provided for @importGpx.
  ///
  /// In en, this message translates to:
  /// **'Import GPX'**
  String get importGpx;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @activityUploaded.
  ///
  /// In en, this message translates to:
  /// **'Activity uploaded'**
  String get activityUploaded;

  /// No description provided for @noActivitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get noActivitiesYet;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @exportGpx.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGpx;

  /// No description provided for @editActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivityTitle;

  /// No description provided for @deleteActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete activity'**
  String get deleteActivityTitle;

  /// No description provided for @deleteActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete activity'**
  String get deleteActivityMessage;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get activityTitle;

  /// No description provided for @activityNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get activityNotes;

  /// No description provided for @trackingActive.
  ///
  /// In en, this message translates to:
  /// **'Tracking:'**
  String get trackingActive;

  /// No description provided for @trackerIdle.
  ///
  /// In en, this message translates to:
  /// **'Tracker idle'**
  String get trackerIdle;

  /// No description provided for @averageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get averageSpeed;

  /// No description provided for @cacheArea.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cacheArea;

  /// No description provided for @selectArea.
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get selectArea;

  /// No description provided for @selectAreaEnabled.
  ///
  /// In en, this message translates to:
  /// **'Area selected'**
  String get selectAreaEnabled;

  /// No description provided for @cachedTiles.
  ///
  /// In en, this message translates to:
  /// **'Cached tiles'**
  String get cachedTiles;

  /// No description provided for @cacheError.
  ///
  /// In en, this message translates to:
  /// **'Cache error'**
  String get cacheError;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @startActivity.
  ///
  /// In en, this message translates to:
  /// **'Start activity'**
  String get startActivity;

  /// No description provided for @stopActivity.
  ///
  /// In en, this message translates to:
  /// **'Stop activity'**
  String get stopActivity;

  /// No description provided for @stopActivityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Finish and save current activity?'**
  String get stopActivityConfirm;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @settingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Settings updated'**
  String get settingsUpdated;

  /// No description provided for @bluetoothSensors.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth sensors'**
  String get bluetoothSensors;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @savedDevices.
  ///
  /// In en, this message translates to:
  /// **'Saved devices'**
  String get savedDevices;

  /// No description provided for @noSavedSensors.
  ///
  /// In en, this message translates to:
  /// **'No saved sensors'**
  String get noSavedSensors;

  /// No description provided for @nearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get nearbyDevices;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownDevice;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @gpsTracking.
  ///
  /// In en, this message translates to:
  /// **'GPS & Tracking'**
  String get gpsTracking;

  /// No description provided for @gpsAccuracyMode.
  ///
  /// In en, this message translates to:
  /// **'Accuracy mode'**
  String get gpsAccuracyMode;

  /// No description provided for @gpsAccuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'High (GPS)'**
  String get gpsAccuracyHigh;

  /// No description provided for @gpsAccuracyBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced (GPS + network)'**
  String get gpsAccuracyBalanced;

  /// No description provided for @gpsAccuracyLow.
  ///
  /// In en, this message translates to:
  /// **'Low power'**
  String get gpsAccuracyLow;

  /// No description provided for @minDistanceBetweenPoints.
  ///
  /// In en, this message translates to:
  /// **'Min distance between points'**
  String get minDistanceBetweenPoints;

  /// No description provided for @syncAndCache.
  ///
  /// In en, this message translates to:
  /// **'Sync and cache'**
  String get syncAndCache;

  /// No description provided for @uploadEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Upload endpoint'**
  String get uploadEndpoint;

  /// No description provided for @apiPassword.
  ///
  /// In en, this message translates to:
  /// **'API password'**
  String get apiPassword;

  /// No description provided for @apiPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter server-generated API password'**
  String get apiPasswordHint;

  /// No description provided for @mapCacheFolder.
  ///
  /// In en, this message translates to:
  /// **'Map cache folder'**
  String get mapCacheFolder;

  /// No description provided for @saveTrackingSettings.
  ///
  /// In en, this message translates to:
  /// **'Save tracking settings'**
  String get saveTrackingSettings;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @tabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabGear.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get tabGear;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @themeTab.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTab;

  /// No description provided for @mapSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapSettingsTab;

  /// No description provided for @coachTab.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachTab;

  /// No description provided for @systemTab.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTab;

  /// No description provided for @profileAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get profileAnonymous;

  /// No description provided for @profilePersonalData.
  ///
  /// In en, this message translates to:
  /// **'Personal data'**
  String get profilePersonalData;

  /// No description provided for @profileHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get profileHeight;

  /// No description provided for @profileWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get profileWeight;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profileMaxHr.
  ///
  /// In en, this message translates to:
  /// **'Max HR'**
  String get profileMaxHr;

  /// No description provided for @profileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileGender;

  /// No description provided for @profileMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profileMale;

  /// No description provided for @profileFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profileFemale;

  /// No description provided for @profileNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get profileNA;

  /// No description provided for @profileLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get profileLoading;

  /// No description provided for @profileRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh from server'**
  String get profileRefresh;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Color (Android 12+)'**
  String get dynamicColor;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @pickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick color'**
  String get pickColor;

  /// No description provided for @bgColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get bgColor;

  /// No description provided for @enableGradient.
  ///
  /// In en, this message translates to:
  /// **'Enable gradient'**
  String get enableGradient;

  /// No description provided for @gradientColor.
  ///
  /// In en, this message translates to:
  /// **'Gradient color'**
  String get gradientColor;

  /// No description provided for @topographicMap.
  ///
  /// In en, this message translates to:
  /// **'Topographic map'**
  String get topographicMap;

  /// No description provided for @mapTheme.
  ///
  /// In en, this message translates to:
  /// **'Map theme'**
  String get mapTheme;

  /// No description provided for @mapThemeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get mapThemeAuto;

  /// No description provided for @mapThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get mapThemeLight;

  /// No description provided for @mapThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get mapThemeDark;

  /// No description provided for @matchSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'Match system theme'**
  String get matchSystemTheme;

  /// No description provided for @mapBehavior.
  ///
  /// In en, this message translates to:
  /// **'Map behavior while tracking'**
  String get mapBehavior;

  /// No description provided for @mapBehaviorDesc.
  ///
  /// In en, this message translates to:
  /// **'Controls how the map responds to your movement during a tracking session.'**
  String get mapBehaviorDesc;

  /// No description provided for @mapBehaviorOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mapBehaviorOff;

  /// No description provided for @mapBehaviorOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Map stays in place'**
  String get mapBehaviorOffDesc;

  /// No description provided for @mapBehaviorFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow location'**
  String get mapBehaviorFollow;

  /// No description provided for @mapBehaviorFollowDesc.
  ///
  /// In en, this message translates to:
  /// **'Center on GPS position'**
  String get mapBehaviorFollowDesc;

  /// No description provided for @mapBehaviorFollowHeading.
  ///
  /// In en, this message translates to:
  /// **'Follow + heading'**
  String get mapBehaviorFollowHeading;

  /// No description provided for @mapBehaviorFollowHeadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Rotate map with compass'**
  String get mapBehaviorFollowHeadingDesc;

  /// No description provided for @gpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get gpsAccuracy;

  /// No description provided for @distanceFilter.
  ///
  /// In en, this message translates to:
  /// **'Distance filter (m)'**
  String get distanceFilter;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'meters'**
  String get meters;

  /// No description provided for @mapCache.
  ///
  /// In en, this message translates to:
  /// **'Map cache'**
  String get mapCache;

  /// No description provided for @cacheFolder.
  ///
  /// In en, this message translates to:
  /// **'Cache folder'**
  String get cacheFolder;

  /// No description provided for @voiceCoach.
  ///
  /// In en, this message translates to:
  /// **'Voice coach'**
  String get voiceCoach;

  /// No description provided for @voiceGender.
  ///
  /// In en, this message translates to:
  /// **'Voice gender'**
  String get voiceGender;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @twoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two-factor auth (MFA)'**
  String get twoFactorAuth;

  /// No description provided for @mfaSecretHelper.
  ///
  /// In en, this message translates to:
  /// **'TOTP secret key for two-factor authentication'**
  String get mfaSecretHelper;

  /// No description provided for @mfaSecretDesc.
  ///
  /// In en, this message translates to:
  /// **'If you have 2FA enabled on your account, save the TOTP secret (from the authenticator app) here so the app can generate verification codes automatically.'**
  String get mfaSecretDesc;

  /// No description provided for @dataUpload.
  ///
  /// In en, this message translates to:
  /// **'Data upload'**
  String get dataUpload;

  /// No description provided for @clearLocalCache.
  ///
  /// In en, this message translates to:
  /// **'Clear local cache'**
  String get clearLocalCache;

  /// No description provided for @clearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get clearCacheTitle;

  /// No description provided for @clearCacheMsg.
  ///
  /// In en, this message translates to:
  /// **'This will remove all locally stored activity and fitness data.'**
  String get clearCacheMsg;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchHint;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allTypes;

  /// No description provided for @filterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get filterByStatus;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @inCloud.
  ///
  /// In en, this message translates to:
  /// **'In cloud'**
  String get inCloud;

  /// No description provided for @pendingUpload.
  ///
  /// In en, this message translates to:
  /// **'Pending upload'**
  String get pendingUpload;

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload error'**
  String get uploadError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again — fields are pre-filled.'**
  String get sessionExpired;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get serverError;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileUpdateFailed;

  /// No description provided for @healthTab.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get healthTab;

  /// No description provided for @healthSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get healthSummary;

  /// No description provided for @healthWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get healthWeight;

  /// No description provided for @healthSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get healthSleep;

  /// No description provided for @healthWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get healthWater;

  /// No description provided for @healthSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get healthSteps;

  /// No description provided for @todaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today\'s summary'**
  String get todaySummary;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @todayDrunk.
  ///
  /// In en, this message translates to:
  /// **'Drunk today'**
  String get todayDrunk;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noWaterRecords.
  ///
  /// In en, this message translates to:
  /// **'No water records'**
  String get noWaterRecords;

  /// No description provided for @glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get glass;

  /// No description provided for @bottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get bottle;

  /// No description provided for @editVolume.
  ///
  /// In en, this message translates to:
  /// **'Edit volume (ml)'**
  String get editVolume;

  /// No description provided for @deleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get deleteRecord;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteRecordConfirm;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// No description provided for @weeklyStats.
  ///
  /// In en, this message translates to:
  /// **'Weekly stats'**
  String get weeklyStats;

  /// No description provided for @editSteps.
  ///
  /// In en, this message translates to:
  /// **'Edit steps'**
  String get editSteps;

  /// No description provided for @stepsHistory.
  ///
  /// In en, this message translates to:
  /// **'Steps history'**
  String get stepsHistory;

  /// No description provided for @noSleepRecords.
  ///
  /// In en, this message translates to:
  /// **'No sleep records'**
  String get noSleepRecords;

  /// No description provided for @noWeightRecords.
  ///
  /// In en, this message translates to:
  /// **'No weight records'**
  String get noWeightRecords;

  /// No description provided for @addWeight.
  ///
  /// In en, this message translates to:
  /// **'Add weight'**
  String get addWeight;

  /// No description provided for @addSleep.
  ///
  /// In en, this message translates to:
  /// **'Add sleep'**
  String get addSleep;

  /// No description provided for @bedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get bedtime;

  /// No description provided for @wakeTime.
  ///
  /// In en, this message translates to:
  /// **'Wake time'**
  String get wakeTime;

  /// No description provided for @totalSleep.
  ///
  /// In en, this message translates to:
  /// **'Total sleep'**
  String get totalSleep;

  /// No description provided for @sleepQuality.
  ///
  /// In en, this message translates to:
  /// **'Sleep quality'**
  String get sleepQuality;

  /// No description provided for @feedMyFeed.
  ///
  /// In en, this message translates to:
  /// **'My feed'**
  String get feedMyFeed;

  /// No description provided for @feedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get feedSubscriptions;

  /// No description provided for @feedEmptyMy.
  ///
  /// In en, this message translates to:
  /// **'No activities in cloud yet'**
  String get feedEmptyMy;

  /// No description provided for @feedEmptyFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends feed is empty'**
  String get feedEmptyFriends;

  /// No description provided for @activityMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving time'**
  String get activityMoving;

  /// No description provided for @activityMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get activityMaxSpeed;

  /// No description provided for @activityAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get activityAvgSpeed;

  /// No description provided for @activityElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain'**
  String get activityElevation;

  /// No description provided for @activityNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get activityNoNotes;

  /// No description provided for @activityAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get activityAddPhoto;

  /// No description provided for @activityDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete activity?'**
  String get activityDeleteTitle;

  /// No description provided for @activityDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get activityDeleteMsg;

  /// No description provided for @activityTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get activityTryAgain;

  /// No description provided for @activityDisplayError.
  ///
  /// In en, this message translates to:
  /// **'Display error'**
  String get activityDisplayError;

  /// No description provided for @activityCouldNotDisplay.
  ///
  /// In en, this message translates to:
  /// **'Could not display activity:'**
  String get activityCouldNotDisplay;

  /// No description provided for @activityCharts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get activityCharts;

  /// No description provided for @activitySpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get activitySpeed;

  /// No description provided for @activityAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get activityAltitude;

  /// No description provided for @activitySplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get activitySplit;

  /// No description provided for @activitySplitPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get activitySplitPace;

  /// No description provided for @activitySplitElev.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get activitySplitElev;

  /// No description provided for @activityPR.
  ///
  /// In en, this message translates to:
  /// **'Personal record'**
  String get activityPR;

  /// No description provided for @activityPRBadge.
  ///
  /// In en, this message translates to:
  /// **'New PR!'**
  String get activityPRBadge;

  /// No description provided for @gearNotFound.
  ///
  /// In en, this message translates to:
  /// **'No gear found'**
  String get gearNotFound;

  /// No description provided for @gearPrimary.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get gearPrimary;

  /// No description provided for @gearMakePrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary for:'**
  String get gearMakePrimary;

  /// No description provided for @gearDefaultCats.
  ///
  /// In en, this message translates to:
  /// **'No default categories for this gear type'**
  String get gearDefaultCats;

  /// No description provided for @gearClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get gearClose;

  /// No description provided for @gearTotalKm.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get gearTotalKm;

  /// No description provided for @gearPurchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Purchase cost'**
  String get gearPurchaseCost;

  /// No description provided for @gearPartsCost.
  ///
  /// In en, this message translates to:
  /// **'Parts cost'**
  String get gearPartsCost;

  /// No description provided for @notifSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get notifSyncComplete;

  /// No description provided for @notifSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get notifSync;

  /// No description provided for @notifSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get notifSyncStatus;

  /// No description provided for @settingsStatsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Stats display'**
  String get settingsStatsDisplay;

  /// No description provided for @settingsStatsRings.
  ///
  /// In en, this message translates to:
  /// **'Ring indicators'**
  String get settingsStatsRings;

  /// No description provided for @settingsStatsCards.
  ///
  /// In en, this message translates to:
  /// **'Card grid'**
  String get settingsStatsCards;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @loginWithSSO.
  ///
  /// In en, this message translates to:
  /// **'Sign in with SSO'**
  String get loginWithSSO;

  /// No description provided for @trackingDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get trackingDistance;

  /// No description provided for @trackingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get trackingDuration;

  /// No description provided for @trackingCurrentSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get trackingCurrentSpeed;

  /// No description provided for @trackingElevationGain.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get trackingElevationGain;

  /// No description provided for @healthHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get healthHeartRate;

  /// No description provided for @importFromHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Import from Health Connect'**
  String get importFromHealthConnect;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported: {count} records'**
  String importSummary(Object count);

  /// No description provided for @hrZoneRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get hrZoneRest;

  /// No description provided for @hrZoneFatBurn.
  ///
  /// In en, this message translates to:
  /// **'Fat Burn'**
  String get hrZoneFatBurn;

  /// No description provided for @hrZoneCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get hrZoneCardio;

  /// No description provided for @hrZonePeak.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get hrZonePeak;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importing;

  /// No description provided for @noHeartRateRecords.
  ///
  /// In en, this message translates to:
  /// **'No heart rate records'**
  String get noHeartRateRecords;

  /// No description provided for @healthConnectNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is not available on this device'**
  String get healthConnectNotAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
