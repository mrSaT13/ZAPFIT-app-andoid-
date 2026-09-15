# ZAPFIT v0.8.7+29 — 2026-09-02
## Исправления кодировки
- Все правки теперь через UTF-8, без поломки кириллицы. Проверено: 0 bad chars.

## Справочник
- Добавлен поиск по справочнику в about_page.dart: TextField с фильтром по заголовку/содержимому, чип очистки, conditional rendering секций через matches().
- Добавлен раздел "New Features ZAPFIT" с описанием 0.8.6 фич.

## История
- activities_screen.dart: subtitle теперь показывает вид + дистанция + дата/время старта + длительность (_formatDate/_formatDuration). Время добавлено.

## Уведомления
- notification_service.dart: WebSocket и polling теперь вызывают LocalNotificationService.showServerNotification для системного трея. Использует title/message из NotificationRecord, id как notificationId.

## Карта в редактировании
- edit_activity_screen.dart: добавлены импорты flutter_map/latlong2/map_constants, метод _showMapPicker() с DraggableScrollableSheet, FlutterMap onTap добавляет ActivityPoint с расчетом дистанции через Distance().as(), кнопка "Add on map" над списком точек. Точки сохраняются локально и уйдут на сервер при следующем GPX upload (uploadStatus pending).

## Нагрузка RPE/TSS
- activity_detail_screen.dart: добавлено поле _savedRpe, в _computeZapfitMetrics загружается getRpe() и пересчитывается TSS через RpeToTssCalculator, в спортивном блоке секция "Нагрузка (RPE)" с RPE и TSS по RPE. Без редактирования теперь видно.

## Сервер
- Проверка activity_upload_service.dart: на сервер уходит name, description, activity_type, visibility, gear_id + ZAPFIT метрики (vo2max, tss, hr_tss, trimp, intensity_factor, aerobic_te, anaerobic_te, epoc, suffer_score, efficiency_factor) + media (gallery + photoPath). Точки трека для новых активностей via GPX, для существующих — только метаданные (GPX не перезаливается, точки остаются локально до реализации re-upload).

## Версия
- pubspec 0.8.7+29 подхватывается автоматически через PackageInfo.fromPlatform() в about_page.dart:22 и settings_screen.dart:177 — ручной ввод не нужен.

## Сборка
- ZAPFIT-v0.8.7+29-release.apk
