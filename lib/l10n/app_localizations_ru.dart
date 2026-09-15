// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get error => 'Ошибка';

  @override
  String get ok => 'ОК';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get back => 'Назад';

  @override
  String get requiredField => 'Это поле обязательно';

  @override
  String get invalidUrl => 'Введите корректный URL';

  @override
  String get loginTitle => 'Вход';

  @override
  String get login => 'Войти';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutConfirmTitle => 'Выход';

  @override
  String get logoutConfirmMessage => 'Вы уверены, что хотите выйти?';

  @override
  String get logoutServerFailedWarning =>
      'Не удалось выйти на сервере, но локальный выход выполнен';

  @override
  String get retry => 'Повторить';

  @override
  String get ssoWebViewTitle => 'Вход';

  @override
  String get ssoCancel => 'Отмена';

  @override
  String ssoSignInWith(String provider) {
    return 'Войти через $provider';
  }

  @override
  String get ssoOrDivider => 'ИЛИ';

  @override
  String get next => 'Далее';

  @override
  String get username => 'Имя пользователя';

  @override
  String get usernameHint => 'Введите имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get passwordHint => 'Введите пароль';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get mfaTitle => 'Двухфакторная аутентификация';

  @override
  String get mfaCode => 'Код MFA';

  @override
  String get mfaCodeHint => 'Введите 6-значный код';

  @override
  String get mfaCodeRequired => 'Введите код MFA';

  @override
  String get verify => 'Подтвердить';

  @override
  String get mapTab => 'Карта';

  @override
  String get activitiesTab => 'Активности';

  @override
  String get settingsTab => 'Настройки';

  @override
  String get settingsScreen => 'Настройки';

  @override
  String get serverSettings => 'Сервер';

  @override
  String get serverSettingsTitle => 'Настройки сервера';

  @override
  String get loggedIn => 'Выполнен вход';

  @override
  String get serverUrl => 'URL сервера';

  @override
  String get serverUrlHint => 'https://example.com';

  @override
  String get tileServerUrl => 'URL тайлового сервера';

  @override
  String get tileServerUrlHint => 'https://tile.openstreetmap.org/...';

  @override
  String get savedSuccessfully => 'Настройки успешно сохранены';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languagePortuguese => 'Португальский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get activitiesTitle => 'Активности';

  @override
  String get activityDetailsTitle => 'Детали активности';

  @override
  String get activityType => 'Тип';

  @override
  String get activityDistance => 'Дистанция';

  @override
  String get activityDuration => 'Время';

  @override
  String get activityPoints => 'Точки GPS';

  @override
  String get activityUploadStatus => 'Статус загрузки';

  @override
  String get activityKindRunning => 'Бег';

  @override
  String get activityKindCycling => 'Велосипед';

  @override
  String get activityKindWalking => 'Ходьба';

  @override
  String get activityKindHiking => 'Треккинг';

  @override
  String get activityKindWorkout => 'Тренировка';

  @override
  String get uploadStatusPending => 'Ожидает';

  @override
  String get uploadStatusUploaded => 'Загружено';

  @override
  String get uploadStatusFailed => 'Ошибка';

  @override
  String get importGpx => 'Импорт GPX';

  @override
  String get importFailed => 'Ошибка импорта';

  @override
  String get exportFailed => 'Ошибка экспорта';

  @override
  String get uploadFailed => 'Ошибка загрузки';

  @override
  String get activityUploaded => 'Активность загружена';

  @override
  String get noActivitiesYet => 'Пока нет активностей';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get upload => 'Загрузить';

  @override
  String get exportGpx => 'Экспорт GPX';

  @override
  String get editActivityTitle => 'Редактировать активность';

  @override
  String get deleteActivityTitle => 'Удалить активность';

  @override
  String get deleteActivityMessage => 'Удалить активность';

  @override
  String get activityTitle => 'Название';

  @override
  String get activityNotes => 'Заметки';

  @override
  String get trackingActive => 'Трекинг:';

  @override
  String get trackerIdle => 'Трекер не активен';

  @override
  String get averageSpeed => 'Средняя скорость';

  @override
  String get cacheArea => 'Кешировать';

  @override
  String get selectArea => 'Выбрать область';

  @override
  String get selectAreaEnabled => 'Область выбрана';

  @override
  String get cachedTiles => 'Кешировано тайлов';

  @override
  String get cacheError => 'Ошибка кеша';

  @override
  String get start => 'Старт';

  @override
  String get stop => 'Стоп';

  @override
  String get pause => 'Пауза';

  @override
  String get resume => 'Продолжить';

  @override
  String get startActivity => 'Начать активность';

  @override
  String get stopActivity => 'Остановить активность';

  @override
  String get stopActivityConfirm => 'Завершить и сохранить текущую активность?';

  @override
  String get myLocation => 'Моё местоположение';

  @override
  String get settingsUpdated => 'Настройки обновлены';

  @override
  String get bluetoothSensors => 'Bluetooth-датчики';

  @override
  String get scan => 'Сканировать';

  @override
  String get savedDevices => 'Сохранённые устройства';

  @override
  String get noSavedSensors => 'Нет сохранённых датчиков';

  @override
  String get nearbyDevices => 'Устройства рядом';

  @override
  String get unknownDevice => 'Неизвестное устройство';

  @override
  String get add => 'Добавить';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get themeMode => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get gpsTracking => 'GPS и трекинг';

  @override
  String get gpsAccuracyMode => 'Режим точности';

  @override
  String get gpsAccuracyHigh => 'Высокая (GPS)';

  @override
  String get gpsAccuracyBalanced => 'Сбалансированная (GPS + сеть)';

  @override
  String get gpsAccuracyLow => 'Энергосбережение';

  @override
  String get minDistanceBetweenPoints => 'Мин. расстояние между точками';

  @override
  String get syncAndCache => 'Синхронизация и кеш';

  @override
  String get uploadEndpoint => 'Эндпоинт загрузки';

  @override
  String get apiPassword => 'Пароль API';

  @override
  String get apiPasswordHint => 'Введите пароль API сервера';

  @override
  String get mapCacheFolder => 'Папка кеша карты';

  @override
  String get saveTrackingSettings => 'Сохранить настройки трекинга';

  @override
  String get notConfigured => 'Не настроено';

  @override
  String get notLoggedIn => 'Не выполнен вход';

  @override
  String get tabRecord => 'Запись';

  @override
  String get tabHistory => 'История';

  @override
  String get tabGear => 'Снаряжение';

  @override
  String get profileTab => 'Профиль';

  @override
  String get themeTab => 'Внешний вид';

  @override
  String get mapSettingsTab => 'Карта';

  @override
  String get coachTab => 'Тренер';

  @override
  String get systemTab => 'Система';

  @override
  String get profileAnonymous => 'Аноним';

  @override
  String get profilePersonalData => 'Личные данные';

  @override
  String get profileHeight => 'Рост (см)';

  @override
  String get profileWeight => 'Вес (кг)';

  @override
  String get profileCity => 'Город';

  @override
  String get profileMaxHr => 'Макс. ЧСС';

  @override
  String get profileGender => 'Пол';

  @override
  String get profileMale => 'Мужской';

  @override
  String get profileFemale => 'Женский';

  @override
  String get profileNA => 'Н/Д';

  @override
  String get profileLoading => 'Загрузка...';

  @override
  String get profileRefresh => 'Обновить с сервера';

  @override
  String get dynamicColor => 'Динамический цвет (Android 12+)';

  @override
  String get accentColor => 'Цвет акцента';

  @override
  String get pickColor => 'Выбрать цвет';

  @override
  String get bgColor => 'Цвет фона';

  @override
  String get enableGradient => 'Включить градиент';

  @override
  String get gradientColor => 'Цвет градиента';

  @override
  String get topographicMap => 'Топографическая карта';

  @override
  String get mapTheme => 'Тема карты';

  @override
  String get mapThemeAuto => 'Авто';

  @override
  String get mapThemeLight => 'Светлая';

  @override
  String get mapThemeDark => 'Тёмная';

  @override
  String get matchSystemTheme => 'Следовать теме системы';

  @override
  String get mapBehavior => 'Поведение карты при трекинге';

  @override
  String get mapBehaviorDesc =>
      'Определяет, как карта реагирует на ваше движение во время записи.';

  @override
  String get mapBehaviorOff => 'Выключено';

  @override
  String get mapBehaviorOffDesc => 'Карта остаётся на месте';

  @override
  String get mapBehaviorFollow => 'Следовать за позицией';

  @override
  String get mapBehaviorFollowDesc => 'Центрировать по GPS';

  @override
  String get mapBehaviorFollowHeading => 'Следовать + ориентация';

  @override
  String get mapBehaviorFollowHeadingDesc => 'Поворачивать карту по компасу';

  @override
  String get gpsAccuracy => 'Точность';

  @override
  String get distanceFilter => 'Фильтр расстояния (м)';

  @override
  String get meters => 'метров';

  @override
  String get mapCache => 'Кеш карты';

  @override
  String get cacheFolder => 'Папка кеша';

  @override
  String get voiceCoach => 'Голосовой тренер';

  @override
  String get voiceGender => 'Пол голоса';

  @override
  String get speechRate => 'Скорость речи';

  @override
  String get volume => 'Громкость';

  @override
  String get twoFactorAuth => 'Двухфакторная аутентификация (MFA)';

  @override
  String get mfaSecretHelper => 'Секретный ключ TOTP для 2FA';

  @override
  String get mfaSecretDesc =>
      'Если у вас включена 2FA, сохраните TOTP-секрет (из приложения-аутентификатора) здесь — приложение сможет автоматически генерировать коды подтверждения.';

  @override
  String get dataUpload => 'Загрузка данных';

  @override
  String get clearLocalCache => 'Очистить локальный кеш';

  @override
  String get clearCacheTitle => 'Очистить кеш?';

  @override
  String get clearCacheMsg =>
      'Будут удалены все локально сохранённые данные активностей и фитнеса.';

  @override
  String get clear => 'Очистить';

  @override
  String get searchHint => 'Поиск по названию...';

  @override
  String get allTypes => 'Все виды';

  @override
  String get filterByStatus => 'Фильтр по статусу';

  @override
  String get allStatuses => 'Все статусы';

  @override
  String get inCloud => 'В облаке';

  @override
  String get pendingUpload => 'Ожидает загрузки';

  @override
  String get uploadError => 'Ошибка загрузки';

  @override
  String get sessionExpired =>
      'Сессия истекла. Войдите ещё раз — поля заполнены автоматически.';

  @override
  String get serverError => 'Ошибка сервера';

  @override
  String get profileUpdateFailed => 'Не удалось обновить профиль';

  @override
  String get healthTab => 'Здоровье';

  @override
  String get healthSummary => 'Сводка';

  @override
  String get healthWeight => 'Вес';

  @override
  String get healthSleep => 'Сон';

  @override
  String get healthWater => 'Вода';

  @override
  String get healthSteps => 'Шаги';

  @override
  String get todaySummary => 'Сводка за сегодня';

  @override
  String get noData => 'Нет данных';

  @override
  String get quality => 'Качество';

  @override
  String get goal => 'Цель';

  @override
  String get todayDrunk => 'Выпито сегодня';

  @override
  String get history => 'История';

  @override
  String get noWaterRecords => 'Нет записей о воде';

  @override
  String get glass => 'Стакан';

  @override
  String get bottle => 'Бутылка';

  @override
  String get editVolume => 'Изменить объём (мл)';

  @override
  String get deleteRecord => 'Удалить запись';

  @override
  String get deleteRecordConfirm => 'Это действие невозможно отменить.';

  @override
  String get editEntry => 'Изменить';

  @override
  String get weeklyStats => 'Статистика за неделю';

  @override
  String get editSteps => 'Редактировать шаги';

  @override
  String get stepsHistory => 'История шагов';

  @override
  String get noSleepRecords => 'Нет записей о сне';

  @override
  String get noWeightRecords => 'Нет записей о весе';

  @override
  String get addWeight => 'Добавить вес';

  @override
  String get addSleep => 'Добавить сон';

  @override
  String get bedtime => 'Время сна';

  @override
  String get wakeTime => 'Время подъёма';

  @override
  String get totalSleep => 'Общий сон';

  @override
  String get sleepQuality => 'Качество сна';

  @override
  String get feedMyFeed => 'Моя лента';

  @override
  String get feedSubscriptions => 'Подписки';

  @override
  String get feedEmptyMy => 'Пока нет активностей в облаке';

  @override
  String get feedEmptyFriends => 'Лента друзей пуста';

  @override
  String get activityMoving => 'Время в движении';

  @override
  String get activityMaxSpeed => 'Макс. скорость';

  @override
  String get activityAvgSpeed => 'Средняя скорость';

  @override
  String get activityElevation => 'Набор высоты';

  @override
  String get activityNoNotes => 'Нет заметок';

  @override
  String get activityAddPhoto => 'Добавить фото';

  @override
  String get activityDeleteTitle => 'Удалить активность?';

  @override
  String get activityDeleteMsg => 'Это действие нельзя отменить.';

  @override
  String get activityTryAgain => 'Попробовать снова';

  @override
  String get activityDisplayError => 'Ошибка отображения';

  @override
  String get activityCouldNotDisplay => 'Не удалось отобразить активность:';

  @override
  String get activityCharts => 'Графики';

  @override
  String get activitySpeed => 'Скорость';

  @override
  String get activityAltitude => 'Высота';

  @override
  String get activitySplit => 'Круг';

  @override
  String get activitySplitPace => 'Темп';

  @override
  String get activitySplitElev => 'Набор высоты';

  @override
  String get activityPR => 'Личный рекорд';

  @override
  String get activityPRBadge => 'Новый рекорд!';

  @override
  String get gearNotFound => 'Снаряжение не найдено';

  @override
  String get gearPrimary => 'ОСНОВНОЕ';

  @override
  String get gearMakePrimary => 'Сделать основным для:';

  @override
  String get gearDefaultCats =>
      'Для данного типа снаряжения нет категорий по умолчанию';

  @override
  String get gearClose => 'Закрыть';

  @override
  String get gearTotalKm => 'Суммарный пробег';

  @override
  String get gearPurchaseCost => 'Стоимость покупки';

  @override
  String get gearPartsCost => 'Стоимость запчастей';

  @override
  String get notifSyncComplete => 'Синхронизация завершена';

  @override
  String get notifSync => 'Синхронизация';

  @override
  String get notifSyncStatus => 'Статус синхронизации';

  @override
  String get settingsStatsDisplay => 'Отображение статистики';

  @override
  String get settingsStatsRings => 'Кольцевые индикаторы';

  @override
  String get settingsStatsCards => 'Сетка карточек';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginOr => 'или';

  @override
  String get loginWithSSO => 'Войти через SSO';

  @override
  String get trackingDistance => 'Дистанция';

  @override
  String get trackingDuration => 'Время';

  @override
  String get trackingCurrentSpeed => 'Скорость';

  @override
  String get trackingElevationGain => 'Набор высоты';

  @override
  String get healthHeartRate => 'Пульс';

  @override
  String get importFromHealthConnect => 'Импорт из Health Connect';

  @override
  String importSummary(Object count) {
    return 'Импортировано: $count записей';
  }

  @override
  String get hrZoneRest => 'Отдых';

  @override
  String get hrZoneFatBurn => 'Жиросжигание';

  @override
  String get hrZoneCardio => 'Кардио';

  @override
  String get hrZonePeak => 'Пик';

  @override
  String get importing => 'Импорт...';

  @override
  String get noHeartRateRecords => 'Нет записей пульса';

  @override
  String get healthConnectNotAvailable =>
      'Health Connect недоступен на этом устройстве';
}
