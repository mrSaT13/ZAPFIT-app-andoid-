# ZAPFIT v0.8.8+30 — 2026-09-02
## Карта редактирования — фикс белого экрана
- edit_activity_screen.dart:12 импорты + app_settings_controller, 79 _showMapPicker переписан на StatefulBuilder + SizedBox(height 85%) + ClipRRect, tileUrl берется из AppSettingsController.mapProvider/mapStyle (как в activity_detail_screen.dart:794), TileLayer с maxZoom 18, Polyline strokeWidth 4, Marker 12px с белой обводкой, локализация isRu для заголовка/кнопок/снэкбара (цвет primary, floating, rounded), карта теперь грузит тайлы онлайн и из кэша, точки сразу отображаются (setState + setSheetState).
- Кнопка "Добавить на карте" / "Add on map" локализована через Builder + isRuBtn.
- Снэкбар теперь цветной (primary, белый текст, floating) вместо белого.

## Сервер — редактирование, а не дублирование
- edit_activity_screen.dart:380 pointsChanged детект (toDelete, id null, длина, координаты), если true и serverId != null — DELETE /api/v1/activities/{id}/delete, сброс serverId, ActivityUploadService.uploadActivity с новым GPX, refreshed serverId. Не дублирует, а заменяет запись.

## Язык
- Все строки карты теперь isRu ? ru : en, привязка к Localizations.localeOf(context).languageCode.

## Сборка
- version 0.8.8+30 → ZAPFIT-v0.8.8+30-release.apk
