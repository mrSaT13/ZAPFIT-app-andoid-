<div align="center">
  <img src="assets/logo/logo.png" width="128" height="128">

  # ZAPFIT Mobile

  [![License: AGPL-3.0](https://img.shields.io/github/license/mrSaT13/ZAPFIT-app-andoid-)](LICENSE)
  ![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter)
  ![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-lightgrey)

  **Фитнес-трекер с открытым кодом: тренировки, здоровье, BLE-датчики, офлайн-карты**
</div>

ZAPFIT — кроссплатформенное приложение для учёта тренировок и показателей здоровья.
Изначально основано на [Endurain Mobile](https://github.com/endurain-project/endurain-flutter),
с тех пор глубоко переработано: собственный модуль здоровья, голосовой тренер,
Material You и глубокая интеграция с Android (виджеты, Health Connect, CompanionDeviceManager).

## Возможности

- **Тренировки:** запись GPS-треков, темп/пульс/мощность, зоны, голосовые подсказки, автопауза
- **Здоровье:** вес и ИМТ, сон (фазы и оценка), вода, шаги, пульс — дашборд и история
- **Устройства:** BLE-датчики (пульс, каденс, мощность), Mi Band / Amazfit (эксперимент.),
  шагомер через системные сенсоры и Health Connect
- **Данные:** импорт/экспорт GPX, офлайн-тайлы карт, двусторонняя синхронизация с сервером,
  полный офлайн-режим
- **Сервер:** авторизация, SSO (Keycloak/Authentik/Authelia/Casdoor/Pocket ID), 2FA/TOTP

## Требования

- Flutter 3.38+ (stable), Dart 3.10+
- Android: SDK 34, JDK 17, `minSdk 26`
- Для iOS/macOS: Xcode; для Windows: Visual Studio с C++-тулчейном

Проверено на Flutter 3.44.4.

## Быстрый старт

```bash
git clone https://github.com/mrSaT13/ZAPFIT-app-andoid-.git
cd ZAPFIT
flutter pub get
flutter run                        # запуск в отладке
flutter build apk --debug          # отладочный APK, ключи не нужны
```

## Подпись релиза

```bash
cp android/key.properties.example android/key.properties  # заполнить своим keystore
flutter build apk --release
```

Application ID — `com.dev.zapfit`.

## Сервер

Приложение подключается к серверу по протоколу Endurain API (адрес задаётся в настройках).
Есть режим совместимости с оригинальным сервером и расширенный ZAPFIT-режим метрик
(VO2max, TSS, TRIMP). Сервер ZAPFIT публикуется отдельным репозиторием.

## Структура проекта

```
lib/
  core/        # сервисы, модели, DI, тема, утилиты
  features/    # activities, health, map, auth, devices, feed, settings, ...
  shared/      # общие виджеты
  l10n/        # локализация (en, ru, pt)
android/ ios/ macos/ windows/ web/  # платформенные оболочки
assets/        # логотип, иконки SSO-провайдеров
test/          # тесты
```

Локализация генерируется автоматически (`flutter gen-l10n`, `generate: true`).

## Документация

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — как предложить изменения
- [`SECURITY.md`](SECURITY.md) — сообщение об уязвимостях
- [`TRADEMARK.md`](TRADEMARK.md) — товарные знаки
- [`TEST_CHECKLIST.md`](TEST_CHECKLIST.md) — чек-лист ручного тестирования
- [`RELEASE_NOTES_v0.8.*.md`](RELEASE_NOTES_v0.8.8.md) — история релизов

## Лицензия

AGPL-3.0, см. [`LICENSE`](LICENSE). Основан на Endurain
© João Vítor A. Silva и участники (AGPL-3.0); изменения ZAPFIT — под той же лицензией.
При сетевом использовании модифицированного сервера его исходники тоже должны быть открыты.
