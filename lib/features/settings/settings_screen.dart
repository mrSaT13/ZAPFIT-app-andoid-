import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/local_notification_service.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/health_service.dart';
// import 'package:zapfit/core/services/google_fit_service.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:zapfit/features/settings/bluetooth_sensors_screen.dart';
import 'package:zapfit/features/devices/devices_screen.dart';
import 'package:zapfit/features/onboarding/mode_selection_screen.dart';
import 'package:zapfit/core/services/voice_coach_service.dart';
import 'package:zapfit/core/services/ollama_service.dart';
import 'package:zapfit/core/services/steps_counter_service.dart';
import 'package:zapfit/features/settings/goals_screen.dart';
import 'package:zapfit/features/settings/about_page.dart';
import 'package:zapfit/features/settings/offline_map_download_screen.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:zapfit/core/utils/vo2max_calculator.dart';
import 'package:zapfit/core/services/training_metrics_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingsController _settings = AppSettingsController.instance;
  final UserService _userService = serviceLocator<UserService>();
  final SecureStorageService _storage = SecureStorageService();

  final TextEditingController _uploadEndpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _cacheFolderController = TextEditingController();
  final TextEditingController _mfaSecretController = TextEditingController();

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _maxHrController = TextEditingController();
  final TextEditingController _restingHrController = TextEditingController();
  final TextEditingController _ftpController = TextEditingController();
  final TextEditingController _vo2maxController = TextEditingController();

  final TextEditingController _hrvRmssdController = TextEditingController();
  final TextEditingController _waistCmController = TextEditingController();
  final TextEditingController _hipCmController = TextEditingController();
  final TextEditingController _neckCmController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _ollamaApiKeyController = TextEditingController();
  final TextEditingController _ollamaBaseUrlController = TextEditingController();
  final TextEditingController _ollamaPromptController = TextEditingController();

  String _version = '';

  @override
  void initState() {
    super.initState();
    _uploadEndpointController.text = _settings.uploadEndpoint;
    _apiKeyController.text = _settings.apiKey;
    _cacheFolderController.text = _settings.mapCacheFolder;

    _updateControllersFromSettings();

    _loadMfaSecret();
    _loadOllamaKey();
    _loadVersion();

    _userService.addListener(_onProfileChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userService.fetchProfile();
    });
  }

  void _onProfileChanged() {
    if (mounted) {
      _updateControllersFromSettings();
    }
  }

  void _updateControllersFromSettings() {
    setState(() {
      _heightController.text = _settings.userHeight.toInt().toString();
      _weightController.text = _settings.userWeight.toStringAsFixed(1);
      _cityController.text = _settings.userCity;
      _maxHrController.text = _settings.userMaxHeartRate.toString();
      _restingHrController.text = _settings.userRestingHeartRate.toString();
      _ftpController.text = _settings.userFtp > 0 ? _settings.userFtp.toStringAsFixed(0) : '';
      _vo2maxController.text = _settings.userVo2max > 0 ? _settings.userVo2max.toStringAsFixed(1) : '';
      _ollamaBaseUrlController.text = _settings.ollamaBaseUrl;
      _ollamaPromptController.text = _settings.ollamaPromptTemplate;
      _hrvRmssdController.text = _settings.userHrvRmssd > 0 ? _settings.userHrvRmssd.toStringAsFixed(0) : '';
      _waistCmController.text = _settings.userWaistCm > 0 ? _settings.userWaistCm.toStringAsFixed(1) : '';
      _hipCmController.text = _settings.userHipCm > 0 ? _settings.userHipCm.toStringAsFixed(1) : '';
      _neckCmController.text = _settings.userNeckCm > 0 ? _settings.userNeckCm.toStringAsFixed(1) : '';
      _systolicController.text = _settings.userSystolic > 0 ? _settings.userSystolic.toString() : '';
      _diastolicController.text = _settings.userDiastolic > 0 ? _settings.userDiastolic.toString() : '';
      if (_userService.profile?.email != null) {
        _emailController.text = _userService.profile!.email!;
      }
    });

    // Синхронизируем вес из health records (самый свежий)
    _syncWeightFromHealth();
  }

  Future<void> _syncWeightFromHealth() async {
    try {
      final healthService = serviceLocator<HealthService>();
      if (healthService.weightRecords.isNotEmpty) {
        final latestWeight = healthService.weightRecords.first.weight;
        if (latestWeight > 0 && latestWeight != _settings.userWeight) {
          await _settings.setUserWeight(latestWeight);
          if (mounted) {
            setState(() {
              _weightController.text = latestWeight.toStringAsFixed(1);
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMfaSecret() async {
    final secret = await _storage.getMfaSecret();
    if (secret != null && mounted) setState(() => _mfaSecretController.text = secret);
  }

  Future<void> _loadOllamaKey() async {
    final k = await _settings.getOllamaApiKey();
    final ks = await _storage.getOllamaApiKey();
    final val = ks ?? k;
    if (val != null && mounted) setState(() => _ollamaApiKeyController.text = val);
  }

  @override
  void dispose() {
    _userService.removeListener(_onProfileChanged);
    _uploadEndpointController.dispose();
    _apiKeyController.dispose();
    _cacheFolderController.dispose();
    _mfaSecretController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _maxHrController.dispose();
    _restingHrController.dispose();
    _ftpController.dispose();
    _vo2maxController.dispose();
    _hrvRmssdController.dispose();
    _waistCmController.dispose();
    _hipCmController.dispose();
    _neckCmController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _ollamaApiKeyController.dispose();
    _ollamaBaseUrlController.dispose();
    _ollamaPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${packageInfo.appName} v${packageInfo.version} (build ${packageInfo.buildNumber})\n\u00A9 2024-${DateTime.now().year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.settingsScreen),
              centerTitle: true,
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(icon: const Icon(Icons.person_outline), text: l10n.profileTab),
                  Tab(icon: const Icon(Icons.palette_outlined), text: l10n.themeTab),
                  Tab(icon: const Icon(Icons.map_outlined), text: l10n.mapSettingsTab),
                  Tab(icon: const Icon(Icons.record_voice_over_outlined), text: l10n.coachTab),
                  Tab(icon: const Icon(Icons.settings_outlined), text: l10n.systemTab),
                ],
              ),
            ),
            body: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _safeTab(_buildProfileTab),
                _safeTab(_buildThemeTab),
                _safeTab(_buildMapTab),
                _safeTab(_buildCoachTab),
                _safeTab(_buildSystemTab),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _safeTab(Widget Function(BuildContext) builder) {
    return Builder(
      builder: (context) {
        try {
          return builder(context);
        } catch (e, st) {
          debugPrint('Settings tab build error: $e\n$st');
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bug_report_outlined, size: 56, color: Colors.orange),
                const SizedBox(height: 12),
                const Text('Tab failed to load',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _userService,
      builder: (context, _) {
        final profile = _userService.profile;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickAndUploadPhoto(context),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                      ),
                      child: SecureImage(
                        imageUrl: profile?.photoUrl,
                        width: 100, height: 100, borderRadius: 50,
                        errorWidget: const CircleAvatar(radius: 50, backgroundColor: Colors.blueGrey, child: Icon(Icons.person, size: 50, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(profile?.name ?? l10n.profileAnonymous, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('@${profile?.username ?? "user"}', style: const TextStyle(color: Colors.grey)),
                  if (profile?.email != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(profile!.email!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.profilePersonalData, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(labelText: 'Email', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.email_outlined), fillColor: Colors.black12, filled: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.profileHeight, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.height)),
                    onChanged: (v) => _settings.setUserHeight(double.tryParse(v) ?? 175),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.profileWeight, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.monitor_weight_outlined)),
                    onChanged: (v) => _settings.setUserWeight(double.tryParse(v) ?? 75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: InputDecoration(labelText: l10n.profileCity, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.location_city)),
                    onChanged: (v) => _settings.setUserCity(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxHrController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.profileMaxHr, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.favorite_border)),
                    onChanged: (v) => _settings.setUserMaxHeartRate(int.tryParse(v) ?? 185),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _restingHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Пульс покоя', border: OutlineInputBorder(), prefixIcon: Icon(Icons.favorite)),
                    onChanged: (v) => _settings.setUserRestingHeartRate(int.tryParse(v) ?? 60),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ftpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'FTP (Вт)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flash_on)),
                    onChanged: (v) => _settings.setUserFtp(double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vo2maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'VO2max', border: OutlineInputBorder(), prefixIcon: Icon(Icons.air)),
                    onChanged: (v) => _settings.setUserVo2max(double.tryParse(v) ?? 0),
                  ),
                ),
                const Spacer(), // Empty space to balance the row
              ],
            ),
            const SizedBox(height: 16),

            // ZAPFIT Mode Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ZAPFIT Mode',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text(
                          'Включает расширенные ZAPFIT-метрики (VO2max, TSS, TRIMP и др.) и отправку на новый API. Выключено = совместимость с оригинальным Endurain.',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _settings.zapfitMode,
                    onChanged: (v) => _settings.setZapfitMode(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('Дополнительные данные для ZAPFIT-метрик',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'HRV и обхваты тела используются для расчёта Recovery/Stress score, WHR, WHtR и % жира по Navy/YMCA. Поля пустые? — оставьте пустыми, метрики покажут «Нет данных».',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            TextField(
              controller: _hrvRmssdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'HRV (rMSSD), мс',
                helperText: 'Вариабельность сердечного ритма — мера восстановления. Обычно 20–80 мс (утром, сидя). Нужен для Recovery и Stress score.',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.heart_broken_outlined),
              ),
              onChanged: (v) => _settings.setUserHrvRmssd(double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waistCmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Обхват талии, см',
                      helperText: 'На уровне пупка. Нужен для WHR, WHtR и % жира Navy.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    onChanged: (v) => _settings.setUserWaistCm(double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hipCmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Обхват бёдер, см',
                      helperText: 'Самая широкая часть. Нужен для WHR и Navy (жен).',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    onChanged: (v) => _settings.setUserHipCm(double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _neckCmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Обхват шеи, см',
                      helperText: 'Ниже кадыка. Нужен для % жира Navy.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.accessibility_new),
                    ),
                    onChanged: (v) => _settings.setUserNeckCm(double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'АД систол., мм рт.ст.',
                      helperText: 'Верхнее давление. Для будущих метрик сердечного возраста.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    onChanged: (v) => _settings.setUserSystolic(int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'АД диастол., мм рт.ст.',
                      helperText: 'Нижнее давление.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bloodtype),
                    ),
                    onChanged: (v) => _settings.setUserDiastolic(int.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAutoDetectSection(context),
            const SizedBox(height: 16),
            Text(l10n.profileGender, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'male', label: Text(l10n.profileMale), icon: const Icon(Icons.male)),
                ButtonSegment(value: 'female', label: Text(l10n.profileFemale), icon: const Icon(Icons.female)),
                ButtonSegment(value: 'unspecified', label: Text(l10n.profileNA), icon: const Icon(Icons.remove)),
              ],
              selected: {_settings.userGender},
              onSelectionChanged: (val) => _settings.setUserGender(val.first),
            ),
            const SizedBox(height: 12),

            // Currency selector
            Text('Валюта', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'euro', label: Text('€ (EUR)'), icon: const Icon(Icons.euro)),
                ButtonSegment(value: 'dollar', label: Text('\$ (USD)'), icon: const Icon(Icons.attach_money)),
                ButtonSegment(value: 'pound', label: Text('£ (GBP)'), icon: const Icon(Icons.monetization_on)),
                ButtonSegment(value: 'ruble', label: Text('₽ (RUB)'), icon: const Icon(Icons.currency_ruble)),
              ],
              selected: {_settings.userCurrency},
              onSelectionChanged: (val) => _settings.setUserCurrency(val.first),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Дата рождения'),
              subtitle: Text(
                _settings.userBirthDate != null
                    ? '${_settings.userBirthDate!.day}.${_settings.userBirthDate!.month}.${_settings.userBirthDate!.year} (${_settings.userAge} лет)'
                    : 'Не указана',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _settings.userBirthDate ?? DateTime(now.year - 25, 1, 1),
                  firstDate: DateTime(1920),
                  lastDate: now,
                );
                if (picked != null) {
                  await _settings.setUserBirthDate(picked);
                }
              },
            ),
            const Divider(height: 32),
            ElevatedButton.icon(
              onPressed: _userService.isLoading ? null : () => _userService.fetchProfile(force: true),
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(_userService.isLoading ? l10n.profileLoading : l10n.profileRefresh),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            if (_userService.lastError != null) ...[
              const SizedBox(height: 8),
              Text(_userService.lastError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            // Weight reminder
            Text('Напоминания', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Напоминание о взвешивании'),
              subtitle: Text(
                _settings.weightReminderEnabled
                    ? 'Каждый день в ${_settings.weightReminderHour.toString().padLeft(2, '0')}:${_settings.weightReminderMinute.toString().padLeft(2, '0')}'
                    : 'Выключено',
                style: const TextStyle(fontSize: 12),
              ),
              value: _settings.weightReminderEnabled,
              onChanged: (v) async {
                await _settings.setWeightReminderEnabled(v);
                if (v) _scheduleWeightReminder();
              },
            ),
            if (_settings.weightReminderEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Время напоминания'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _settings.weightReminderHour,
                      minute: _settings.weightReminderMinute,
                    ),
                  );
                  if (picked != null) {
                    await _settings.setWeightReminderTime(picked.hour, picked.minute);
                    _scheduleWeightReminder();
                  }
                },
              ),
            const SizedBox(height: 16),
            // Folder auto-import
            Text('Авто-импорт', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Автоматический импорт из папки'),
              subtitle: Text(
                _settings.folderAutoImportEnabled
                    ? _settings.folderAutoImportPath.isNotEmpty
                        ? _settings.folderAutoImportPath
                        : 'Папка не указана'
                    : 'Выключено',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              value: _settings.folderAutoImportEnabled,
              onChanged: (v) async {
                await _settings.setFolderAutoImportEnabled(v);
              },
            ),
            if (_settings.folderAutoImportEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open),
                title: const Text('Выбрать папку'),
                subtitle: Text(
                  _settings.folderAutoImportPath.isNotEmpty
                      ? _settings.folderAutoImportPath
                      : 'Например: Download (требуется разрешение)',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickImportFolder(context),
              ),
          ],
        );
      },
    );
  }

  Widget _buildThemeTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(l10n.dynamicColor),
          value: _settings.dynamicColorEnabled,
          onChanged: (v) => _settings.setDynamicColorEnabled(v),
        ),
        ListTile(
          title: Text(l10n.themeMode),
          trailing: DropdownButton<ThemeMode>(
            value: _settings.themeMode,
            onChanged: (m) => m != null ? _settings.setThemeMode(m) : null,
            items: [
              DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem)),
              DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
              DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
            ],
          ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.accentColor, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.colorize, size: 18),
              label: Text(l10n.pickColor),
              onPressed: () => _pickColor(
                current: _settings.accentColor,
                onPicked: (c) => _settings.setAccentColor(c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildColorPalette(_settings.accentColor,
            AppSettingsController.accentColors, (c) => _settings.setAccentColor(c)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.bgColor, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.colorize, size: 18),
              label: Text(l10n.pickColor),
              onPressed: () => _pickColor(
                current: _settings.backgroundColor,
                onPicked: (c) => _settings.setBackgroundColor(c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildColorPalette(_settings.backgroundColor,
            AppSettingsController.backgroundColors, (c) => _settings.setBackgroundColor(c)),
        const Divider(height: 32),
        SwitchListTile(
          title: Text(l10n.enableGradient),
          value: _settings.gradientEnabled,
          onChanged: (v) => _settings.setGradientEnabled(v),
        ),
        if (_settings.gradientEnabled) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.gradientColor, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.colorize, size: 18),
                label: Text(l10n.pickColor),
                onPressed: () => _pickColor(
                  current: _settings.gradientAccent ?? _settings.accentColor,
                  onPicked: (c) => _settings.setGradientAccent(c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildColorPalette(
            _settings.gradientAccent ?? Colors.blue,
            AppSettingsController.gradientColors,
            (c) => _settings.setGradientAccent(c),
        ),
        const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Направление градиента', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'linear', label: Text('Линейный'), icon: Icon(Icons.arrow_right_alt)),
                ButtonSegment(value: 'radial', label: Text('Радиальный'), icon: Icon(Icons.circle)),
              ],
              selected: {_settings.gradientDirection},
              onSelectionChanged: (v) => _settings.setGradientDirection(v.first),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorPalette(Color selected, List<Color> palette, Function(Color) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...palette.map((c) => _buildColorOption(c, selected, onSelect)),
        _buildCustomColorButton(onSelect),
      ],
    );
  }

  Widget _buildCustomColorButton(Function(Color) onSelect) {
    return GestureDetector(
      onTap: () => _pickColor(
        current: Colors.white,
        onPicked: onSelect,
      ),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
        ),
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }

  Widget _buildColorOption(Color color, Color selectedColor, Function(Color) onSelect) {
    final isSelected = color.value == selectedColor.value;
    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
          boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  Future<void> _pickColor({required Color current, required ValueChanged<Color> onPicked}) async {
    final l10n = AppLocalizations.of(context)!;
    double r = (current.r * 255.0).round().toDouble().clamp(0, 255);
    double g = (current.g * 255.0).round().toDouble().clamp(0, 255);
    double b = (current.b * 255.0).round().toDouble().clamp(0, 255);
    final hexController = TextEditingController(
      text: (current.r * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase() +
          (current.g * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase() +
          (current.b * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase(),
    );

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          Color liveColor() => Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
          return AlertDialog(
            title: Text(l10n.pickColor),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80, width: double.infinity,
                    decoration: BoxDecoration(
                      color: liveColor(),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _colorSlider('R', Colors.red, r, (v) => setSt(() => r = v), 0, 255),
                  _colorSlider('G', Colors.green, g, (v) => setSt(() => g = v), 0, 255),
                  _colorSlider('B', Colors.blue, b, (v) => setSt(() => b = v), 0, 255),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hexController,
                    decoration: const InputDecoration(
                      labelText: 'HEX (#RRGGBB)',
                      prefixText: '#',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (v) {
                      if (v.length == 6) {
                        final rr = int.tryParse(v.substring(0, 2), radix: 16) ?? 0;
                        final gg = int.tryParse(v.substring(2, 4), radix: 16) ?? 0;
                        final bb = int.tryParse(v.substring(4, 6), radix: 16) ?? 0;
                        setSt(() {
                          r = rr.toDouble();
                          g = gg.toDouble();
                          b = bb.toDouble();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, liveColor()),
                child: Text(l10n.verify),
              ),
            ],
          );
        });
      },
    );
    if (result != null) onPicked(result);
  }

  Widget _colorSlider(String label, Color hint, double value, ValueChanged<double> onChanged, double min, double max) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value, min: min, max: max,
            activeColor: hint,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toInt().toString(), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildMapTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Провайдер карт', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        RadioListTile<MapProvider>(
          title: const Text('OpenStreetMap'),
          subtitle: const Text('Стандартная карта'),
          value: MapProvider.osm,
          groupValue: _settings.mapProvider,
          onChanged: (v) => v != null ? _settings.setMapProvider(v) : null,
        ),
        RadioListTile<MapProvider>(
          title: const Text('OpenTopoMap'),
          subtitle: const Text('Топографическая карта'),
          value: MapProvider.tomapo,
          groupValue: _settings.mapProvider,
          onChanged: (v) => v != null ? _settings.setMapProvider(v) : null,
        ),
        RadioListTile<MapProvider>(
          title: const Text('CartoDB Dark'),
          subtitle: const Text('Тёмная карта'),
          value: MapProvider.cartoDark,
          groupValue: _settings.mapProvider,
          onChanged: (v) => v != null ? _settings.setMapProvider(v) : null,
        ),
        RadioListTile<MapProvider>(
          title: const Text('Спутник (Esri)'),
          subtitle: const Text('Спутниковая карта'),
          value: MapProvider.esriSatellite,
          groupValue: _settings.mapProvider,
          onChanged: (v) => v != null ? _settings.setMapProvider(v) : null,
        ),
        const Divider(),
        Text(l10n.mapTheme, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        RadioListTile<MapTheme>(
          title: Text(l10n.mapThemeAuto),
          subtitle: Text(l10n.matchSystemTheme),
          value: MapTheme.auto,
          groupValue: _settings.mapTheme,
          onChanged: (v) => v != null ? _settings.setMapTheme(v) : null,
        ),
        RadioListTile<MapTheme>(
          title: Text(l10n.mapThemeLight),
          value: MapTheme.light,
          groupValue: _settings.mapTheme,
          onChanged: (v) => v != null ? _settings.setMapTheme(v) : null,
        ),
        RadioListTile<MapTheme>(
          title: Text(l10n.mapThemeDark),
          value: MapTheme.dark,
          groupValue: _settings.mapTheme,
          onChanged: (v) => v != null ? _settings.setMapTheme(v) : null,
        ),
        const Divider(),
        Text(l10n.mapBehavior, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(l10n.mapBehaviorDesc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        RadioListTile<MapDynamicBehavior>(
          title: Text(l10n.mapBehaviorOff),
          subtitle: Text(l10n.mapBehaviorOffDesc),
          value: MapDynamicBehavior.off,
          groupValue: _settings.mapDynamicBehavior,
          onChanged: (v) => v != null ? _settings.setMapDynamicBehavior(v) : null,
        ),
        RadioListTile<MapDynamicBehavior>(
          title: Text(l10n.mapBehaviorFollow),
          subtitle: Text(l10n.mapBehaviorFollowDesc),
          value: MapDynamicBehavior.follow,
          groupValue: _settings.mapDynamicBehavior,
          onChanged: (v) => v != null ? _settings.setMapDynamicBehavior(v) : null,
        ),
        RadioListTile<MapDynamicBehavior>(
          title: Text(l10n.mapBehaviorFollowHeading),
          subtitle: Text(l10n.mapBehaviorFollowHeadingDesc),
          value: MapDynamicBehavior.followWithHeading,
          groupValue: _settings.mapDynamicBehavior,
          onChanged: (v) => v != null ? _settings.setMapDynamicBehavior(v) : null,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_download, color: Colors.teal),
          title: const Text('Оффлайн карты'),
          subtitle: const Text('Скачать тайлы для использования без интернета'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OfflineMapDownloadScreen()),
          ),
        ),
        const Divider(),
        Text(l10n.gpsAccuracy, style: const TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          title: Text(l10n.gpsAccuracyMode),
          trailing: DropdownButton<String>(
            value: _settings.gpsAccuracy,
            onChanged: (v) => v != null ? _settings.setGpsAccuracy(v) : null,
            items: [
              DropdownMenuItem(value: 'low', child: Text(l10n.gpsAccuracyLow)),
              DropdownMenuItem(value: 'medium', child: Text(l10n.gpsAccuracyBalanced)),
              DropdownMenuItem(value: 'high', child: Text(l10n.gpsAccuracyHigh)),
            ],
          ),
        ),
        ListTile(
          title: Text(l10n.distanceFilter),
          subtitle: Text('${_settings.gpsDistanceFilter} ${l10n.meters}'),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: _settings.gpsDistanceFilter.toDouble(),
              min: 0, max: 50,
              divisions: 50,
              label: '${_settings.gpsDistanceFilter} м',
              onChanged: (v) => _settings.setGpsDistanceFilter(v.toInt()),
            ),
          ),
        ),
        ListTile(
          title: const Text('Интервал GPS'),
          subtitle: Text('${_settings.gpsUpdateIntervalSeconds} сек.'),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: _settings.gpsUpdateIntervalSeconds.toDouble(),
              min: 1, max: 30,
              divisions: 29,
              label: '${_settings.gpsUpdateIntervalSeconds} сек.',
              onChanged: (v) => _settings.setGpsUpdateInterval(v.toInt()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Auto-pause section
        const Text('Авто-пауза', style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Авто-пауза при остановке'),
          subtitle: const Text('Пауза при снижении скорости'),
          value: _settings.autoPauseEnabled,
          onChanged: (v) => _settings.setAutoPauseEnabled(v),
        ),
        if (_settings.autoPauseEnabled) ...[
          ListTile(
            title: const Text('Порог скорости'),
            subtitle: Text('${_settings.autoPauseSpeedThreshold.toStringAsFixed(1)} км/ч'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.autoPauseSpeedThreshold,
                min: 0.5, max: 5.0,
                divisions: 9,
                label: '${_settings.autoPauseSpeedThreshold.toStringAsFixed(1)} км/ч',
                onChanged: (v) => _settings.setAutoPauseSpeedThreshold(v),
              ),
            ),
          ),
          ListTile(
            title: const Text('Задержка перед паузой'),
            subtitle: Text('${_settings.autoPauseDelaySeconds} сек.'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _settings.autoPauseDelaySeconds.toDouble(),
                min: 3, max: 30,
                divisions: 27,
                label: '${_settings.autoPauseDelaySeconds} сек.',
                onChanged: (v) => _settings.setAutoPauseDelaySeconds(v.toInt()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.tour, color: Colors.purple),
          title: const Text('Показать тур по приложению'),
          onTap: () {
            _settings.onShowOnboarding?.call();
          },
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz, color: Colors.teal),
          title: const Text('Режим работы'),
          subtitle: const Text('Локальный / Подключение к серверу'),
          onTap: () async {
            final currentMode = await ModeSelectionScreen.getMode();
            if (!mounted) return;
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Режим работы'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<AppMode>(
                      title: const Text('Локальный'),
                      subtitle: const Text('Данные только на устройстве'),
                      value: AppMode.local,
                      groupValue: currentMode,
                      onChanged: (v) async {
                        if (v != null) {
                          await ModeSelectionScreen.setMode(v);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Режим изменён. Перезапустите приложение.')),
                            );
                          }
                        }
                      },
                    ),
                    RadioListTile<AppMode>(
                      title: const Text('Серверный'),
                      subtitle: const Text('Синхронизация с сервером'),
                      value: AppMode.server,
                      groupValue: currentMode,
                      onChanged: (v) async {
                        if (v != null) {
                          await ModeSelectionScreen.setMode(v);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Режим изменён. Перезапустите приложение.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(title: Text(l10n.mapCache)),
        TextField(
          controller: _cacheFolderController,
          decoration: InputDecoration(
            labelText: l10n.cacheFolder, border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.folder_open),
          ),
          onChanged: (v) => _settings.setMapCacheFolder(v),
        ),
      ],
    );
  }

  Widget _buildCoachTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(l10n.voiceCoach),
          value: _settings.voiceCoachEnabled,
          onChanged: (v) => _settings.setVoiceCoachEnabled(v),
        ),
        if (_settings.voiceCoachEnabled) ...[
          ListTile(
            title: Text(l10n.voiceGender),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'male', label: Text(l10n.profileMale)),
                ButtonSegment(value: 'female', label: Text(l10n.profileFemale)),
              ],
              selected: {_settings.voiceCoachGender},
              onSelectionChanged: (v) => _settings.setVoiceCoachGender(v.first),
            ),
          ),
          FutureBuilder<List<MapEntry<String, String>>>(
            future: VoiceCoachService.instance.getAvailableVoices(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final voices = snapshot.data!;
              return ListTile(
                title: const Text('Модель голоса'),
                subtitle: Text(_settings.voiceCoachModel ?? 'Авто (по полу)'),
                trailing: DropdownButton<String?>(
                  value: _settings.voiceCoachModel,
                  onChanged: (v) => _settings.setVoiceCoachModel(v),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Авто (по полу)'),
                    ),
                    ...voices.map((v) => DropdownMenuItem<String?>(
                      value: v.key,
                      child: Text(v.key, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                ),
              );
            },
          ),
          ListTile(
            title: Text(l10n.speechRate),
            subtitle: Slider(
              value: _settings.voiceCoachSpeechRate,
              min: 0.1, max: 1.0,
              onChanged: (v) => _settings.setVoiceCoachSpeechRate(v),
            ),
          ),
          ListTile(
            title: Text(l10n.volume),
            subtitle: Slider(
              value: _settings.voiceCoachVolume,
              min: 0.0, max: 1.0,
              onChanged: (v) => _settings.setVoiceCoachVolume(v),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Объявление километров'),
            subtitle: Text(_settings.voiceCoachAnnounceKm
                ? 'Каждые ${_settings.voiceCoachKmInterval} км'
                : 'Выключено'),
            value: _settings.voiceCoachAnnounceKm,
            onChanged: (v) => _settings.setVoiceCoachAnnounceKm(v),
          ),
          if (_settings.voiceCoachAnnounceKm) ...[
            ListTile(
              title: const Text('Интервал объявления'),
              subtitle: Text('Каждые ${_settings.voiceCoachKmInterval} км'),
              trailing: DropdownButton<int>(
                value: _settings.voiceCoachKmInterval,
                onChanged: (v) => v != null ? _settings.setVoiceCoachKmInterval(v) : null,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 км')),
                  DropdownMenuItem(value: 2, child: Text('2 км')),
                  DropdownMenuItem(value: 5, child: Text('5 км')),
                  DropdownMenuItem(value: 10, child: Text('10 км')),
                ],
              ),
            ),
          ],
          SwitchListTile(
            title: const Text('Обратный отсчёт'),
            subtitle: const Text('Озвучка обратного отсчёта перед стартом'),
            value: _settings.voiceCoachAnnounceCountdown,
            onChanged: (v) => _settings.setVoiceCoachAnnounceCountdown(v),
          ),
          SwitchListTile(
            title: const Text('Мотивационные отметки'),
            subtitle: Text(_settings.voiceCoachAnnounceMilestones
                ? 'Каждые ${_settings.voiceCoachMilestoneInterval} км — поздравление (адаптируется под тип тренировки)'
                : 'Выключено'),
            value: _settings.voiceCoachAnnounceMilestones,
            onChanged: (v) => _settings.setVoiceCoachAnnounceMilestones(v),
          ),
          if (_settings.voiceCoachAnnounceMilestones)
            ListTile(
              title: const Text('Интервал отметок'),
              subtitle: Text('Каждые ${_settings.voiceCoachMilestoneInterval} км — для плавания автоматически в метрах'),
              trailing: DropdownButton<int>(
                value: _settings.voiceCoachMilestoneInterval,
                onChanged: (v) => v != null ? _settings.setVoiceCoachMilestoneInterval(v) : null,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 км')),
                  DropdownMenuItem(value: 2, child: Text('2 км')),
                  DropdownMenuItem(value: 5, child: Text('5 км')),
                  DropdownMenuItem(value: 10, child: Text('10 км')),
                  DropdownMenuItem(value: 21, child: Text('21 км')),
                  DropdownMenuItem(value: 42, child: Text('42 км')),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Поздравление в конце'),
            subtitle: const Text('Итог дистанции и времени после тренировки'),
            value: _settings.voiceCoachAnnounceFinish,
            onChanged: (v) => _settings.setVoiceCoachAnnounceFinish(v),
          ),
          SwitchListTile(
            title: const Text('Предупреждение о пульсе'),
            subtitle: Text(_settings.voiceCoachHrAlertEnabled
                ? 'Когда пульс > макс. (${_settings.userMaxHeartRate} уд/мин)'
                : 'Выключено'),
            value: _settings.voiceCoachHrAlertEnabled,
            onChanged: (v) => _settings.setVoiceCoachHrAlertEnabled(v),
          ),
          SwitchListTile(
            title: const Text('Объявление темпа'),
            subtitle: const Text('Периодическое объявление текущего темпа'),
            value: _settings.voiceCoachAnnouncePace,
            onChanged: (v) => _settings.setVoiceCoachAnnouncePace(v),
          ),
          const Divider(),
          const ListTile(title: Text('ИИ-Анализ (Ollama Cloud)', style: TextStyle(fontWeight: FontWeight.bold))),
          SwitchListTile(
            title: const Text('Включить ИИ-допись анализа'),
            subtitle: Text(_settings.ollamaEnabled ? 'Дополняет анализ тренировки через Ollama Cloud API' : 'Выключено'),
            value: _settings.ollamaEnabled,
            secondary: const Icon(Icons.smart_toy_outlined),
            onChanged: (v) => _settings.setOllamaEnabled(v),
          ),
          if (_settings.ollamaEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _ollamaBaseUrlController,
                decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://ollama.com', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                onChanged: (v) => _settings.setOllamaBaseUrl(v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _ollamaApiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'ollama cloud api key',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: () async {
                    await _settings.setOllamaApiKey(_ollamaApiKeyController.text.trim());
                    await _storage.setOllamaApiKey(_ollamaApiKeyController.text.trim());
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ключ сохранён')));
                  }),
                ),
                obscureText: true,
                onSubmitted: (v) async {
                  await _settings.setOllamaApiKey(v.trim());
                  await _storage.setOllamaApiKey(v.trim());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FutureBuilder<List<String>>(
                future: _settings.getOllamaApiKey().then((k) => OllamaService.instance.listModels(apiKey: k, baseUrl: _settings.ollamaBaseUrl)),
                builder: (context, snapshot) {
                  final models = snapshot.data ?? OllamaService.instance.listModels(apiKey: null, baseUrl: null) as dynamic;
                  // fallback sync list if future not completed
                  final List<String> items = snapshot.hasData ? snapshot.data! : ['kimi-k2.6:cloud','glm-5.1:cloud','glm-5.2:cloud','qwen3.5:397b','deepseek-v4-flash','minimax-m3','gemma4:31b'];
                  final current = _settings.ollamaModel;
                  final allItems = items.contains(current) ? items : [current, ...items];
                  return ListTile(
                    title: const Text('Модель'),
                    subtitle: Text(current),
                    trailing: DropdownButton<String>(
                      value: current,
                      onChanged: (v) => v != null ? _settings.setOllamaModel(v) : null,
                      items: allItems.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _ollamaPromptController,
                decoration: const InputDecoration(labelText: 'Шаблон промпта', helperText: 'Плейсхолдеры: {kind} {distance} {duration} {pace} {speed} {avgHr} {maxHr} {ascent} {tss} {weight} {height} {age} {gender} {bmi} {ftp} {vo2max} {hrv} {waist} {systolic} {sleep} {sleepScore} {water} {steps}', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                maxLines: 4,
                onChanged: (v) => _settings.setOllamaPromptTemplate(v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Модели обновляются через https://ollama.com/api/tags . Актуальные на 2026: kimi-k2.6, glm-5.x, qwen3.5, deepseek-v4, minimax-m3, gemma4', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSystemTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.twoFactorAuth, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: _mfaSecretController,
          decoration: InputDecoration(
            labelText: 'MFA Secret Key',
            helperText: l10n.mfaSecretHelper,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.security),
          ),
          onChanged: (v) => _storage.setMfaSecret(v.trim()),
        ),
        const SizedBox(height: 8),
        Text(l10n.mfaSecretDesc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 24),
        Text('Цели и достижения', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.flag, color: Colors.amber),
          title: const Text('Мои цели'),
          subtitle: const Text('Пробег, тренировки, достижения'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoalsScreen()),
          ),
        ),
        const SizedBox(height: 24),
        Text('Bluetooth-датчики', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.bluetooth, color: Colors.blue),
          title: const Text('Мои устройства'),
          subtitle: const Text('Браслеты, часы, пульсометры, датчики'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DevicesScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bluetooth_searching, color: Colors.teal),
          title: const Text('Датчики для тренировок'),
          subtitle: const Text('Пульсометры, датчики каденции, мощности'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BluetoothSensorsScreen()),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.dataUpload, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: _uploadEndpointController,
          decoration: InputDecoration(labelText: l10n.uploadEndpoint, border: const OutlineInputBorder()),
          onChanged: (v) => _settings.setUploadEndpoint(v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(labelText: 'X-API-Key', border: OutlineInputBorder()),
          onChanged: (v) => _settings.setApiKey(v),
        ),
        const Divider(height: 32),
        Text('Шагомер', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        _buildPedometerSection(context),
        const Divider(height: 32),
        Text('Health Connect', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        // _buildGoogleFitSection(context), // Закомментировано — Google Fit не используется
        const Divider(height: 32),
        Text('Фоновые уведомления', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Опрос уведомлений в фоне'),
          subtitle: const Text('Проверять новые уведомления каждые 30–60 минут'),
          value: _settings.notifPollingEnabled,
          onChanged: (v) => _settings.setNotifPollingEnabled(v),
        ),
        if (_settings.notifPollingEnabled)
          ListTile(
            title: const Text('Интервал опроса'),
            subtitle: Text('${_settings.notifPollingIntervalMinutes} мин'),
            trailing: DropdownButton<int>(
              value: _settings.notifPollingIntervalMinutes,
              onChanged: (v) => v != null ? _settings.setNotifPollingIntervalMinutes(v) : null,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 мин')),
                DropdownMenuItem(value: 45, child: Text('45 мин')),
                DropdownMenuItem(value: 60, child: Text('60 мин')),
              ],
            ),
          ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.delete_sweep, color: Colors.amber),
          title: Text(l10n.clearLocalCache),
          onTap: () => _showClearHealthDataDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
          onTap: widget.onLogout,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          title: const Text('О приложении'),
          subtitle: const Text('Версия, описание, справочник'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutPage()),
          ),
        ),
        const SizedBox(height: 20),
        Text(_version, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showClearHealthDataDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCacheTitle),
        content: Text(l10n.clearCacheMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(context);
              await serviceLocator<HealthService>().clearAllLocalHealthData();
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }

  void _scheduleWeightReminder() {
    final settings = AppSettingsController.instance;
    if (!settings.weightReminderEnabled) return;

    // Schedule daily notification at the configured time
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day,
      settings.weightReminderHour, settings.weightReminderMinute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    LocalNotificationService.instance.scheduleWeightReminder(
      scheduledDate,
      settings.weightReminderHour,
      settings.weightReminderMinute,
    );
  }

  /// Pick a folder for auto-import, handling Android 11+ storage permissions
  Future<void> _pickImportFolder(BuildContext context) async {
    // On Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE to read Download folder
    try {
      const platform = MethodChannel('com.zapfit/storage');
      final int sdkVersion = await platform.invokeMethod('getSdkVersion') ?? 30;
      if (sdkVersion >= 30) {
        final bool hasPermission = await platform.invokeMethod('hasStoragePermission') ?? false;
        if (!hasPermission) {
          if (!context.mounted) return;
          final granted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Доступ к файлам'),
              content: const Text(
                'Для импорта файлов из папки Download нужно разрешить доступ ко всем файлам.\n\n'
                'Нажмите "Разрешить" и в настройках включите "Доступ к файлам" для ZAPFIT.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context, true);
                    await platform.invokeMethod('openStorageSettings');
                  },
                  child: const Text('Разрешить'),
                ),
              ],
            ),
          );
          if (granted != true) return;
          // Give user time to enable the permission
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (_) {
      // Platform channel not available (iOS/web) — just use file_picker
    }

    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      await _settings.setFolderAutoImportPath(path);
    }
  }

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.first.path != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: result.files.first.path!,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Кадрирование фото',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              cropStyle: CropStyle.circle,
            ),
            IOSUiSettings(
              title: 'Кадрирование фото',
              cropStyle: CropStyle.circle,
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
        final filePath = croppedFile?.path ?? result.files.first.path!;
        final response = await serviceLocator<ApiClient>().uploadFile('/api/v1/profile/image', filePath, 'file');
        if (response.statusCode == 201 || response.statusCode == 200) {
          await _userService.fetchProfile(force: true);
        }
      }
    } catch (e) {
      debugPrint('_pickAndUploadPhoto error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPedometerSection(BuildContext context) {
    final steps = StepsCounterService.instance;
    final settings = AppSettingsController.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.watch, size: 20),
            const SizedBox(width: 8),
            const Text('Шагомер', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (steps.isSyncing)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (steps.lastSyncedAt != null)
              Text(
                'Обновлено ${_fmtTime(steps.lastSyncedAt!)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        if (steps.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(steps.lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.stepsAutoSyncEnabled,
          onChanged: (v) async {
            if (v && !settings.stepsHealthPermissionsGranted) {
              final ok = await steps.requestPermissions();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Требуется разрешение на распознавание активности')),
                );
                return;
              }
            }
            await settings.setStepsAutoSyncEnabled(v);
          },
          title: const Text('Авто-синхронизация'),
          subtitle: Text('Источник: ${steps.source == 'pedometer' ? 'Педометр' : steps.source}'),
        ),
        Row(
          children: [
            const Text('Время: '),
            TextButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: settings.stepsSyncHour, minute: 0),
                );
                if (picked != null) await settings.setStepsSyncHour(picked.hour);
              },
              child: Text('${settings.stepsSyncHour.toString().padLeft(2, '0')}:00'),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: steps.isSyncing
                  ? null
                  : () async {
                      if (!settings.stepsHealthPermissionsGranted) {
                        await steps.requestPermissions();
                      }
                      final n = await steps.syncNow(daysBack: 2);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Обновлено $n дней')),
                        );
                      }
                    },
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // === ЗАКОММЕНТИРОВАНО: Google Fit section — заменён на Health Connect ===
  // Widget _buildGoogleFitSection(BuildContext context) {
  //   final gfService = serviceLocator<GoogleFitService>();
  //   return ListenableBuilder(
  //     listenable: gfService,
  //     builder: (context, _) {
  //       return Card(
  //         elevation: 0,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
  //         ),
  //         child: Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 children: [
  //                   const Icon(Icons.fitness_center, size: 20, color: Colors.teal),
  //                   const SizedBox(width: 8),
  //                   const Text('Health Connect', style: TextStyle(fontWeight: FontWeight.bold)),
  //                   const Spacer(),
  //                   if (!gfService.isAvailable)
  //                     TextButton.icon(
  //                       onPressed: () async {
  //                         final ok = await gfService.checkAvailability();
  //                         if (!ok && context.mounted) {
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             const SnackBar(
  //                               content: Text('Health Connect не установлен. Установите из Google Play.'),
  //                               duration: Duration(seconds: 4),
  //                             ),
  //                           );
  //                         } else if (ok && context.mounted) {
  //                           setState(() {});
  //                         }
  //                       },
  //                       icon: const Icon(Icons.refresh, size: 16),
  //                       label: const Text('Проверить', style: TextStyle(fontSize: 12)),
  //                     )
  //                   else
  //                     Switch(
  //                       value: gfService.isEnabled,
  //                       onChanged: (v) async {
  //                         if (v) {
  //                           final ok = await gfService.requestPermissions();
  //                           if (!ok && context.mounted) {
  //                             ScaffoldMessenger.of(context).showSnackBar(
  //                               const SnackBar(content: Text('Разрешение не выдано')),
  //                             );
  //                           }
  //                         } else {
  //                           await gfService.disable();
  //                         }
  //                       },
  //                     ),
  //                 ],
  //               ),
  //               if (!gfService.isAvailable)
  //                 const Padding(
  //                   padding: EdgeInsets.only(top: 4),
  //                   child: Text(
  //                     'Установите Health Connect из Google Play для синхронизации данных',
  //                     style: TextStyle(fontSize: 11, color: Colors.grey),
  //                   ),
  //                 ),
  //               if (gfService.isEnabled) ...[
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   gfService.lastSyncTime != null
  //                       ? 'Последняя синхронизация: ${gfService.lastSyncTime!.day}.${gfService.lastSyncTime!.month}.${gfService.lastSyncTime!.year}'
  //                       : 'Синхронизация ещё не выполнялась',
  //                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 SizedBox(
  //                   width: double.infinity,
  //                   child: FilledButton.tonalIcon(
  //                     onPressed: gfService.isSyncing ? null : () async {
  //                       final healthService = serviceLocator<HealthService>();
  //                       final result = await gfService.syncAll(daysBack: 7);
  //                       for (final s in result.steps) {
  //                         await healthService.addStepsRecord(s.steps);
  //                       }
  //                       for (final s in result.sleep) {
  //                         await healthService.addSleep(s);
  //                       }
  //                       for (final hr in result.heartRate) {
  //                         await healthService.addHeartRate(hr);
  //                       }
  //                       if (result.weight.isNotEmpty) {
  //                         final latest = result.weight.last;
  //                         await healthService.addWeightWithComposition(latest);
  //                       }
  //                       if (context.mounted) {
  //                         ScaffoldMessenger.of(context).showSnackBar(
  //                           SnackBar(content: Text('Синхронизировано: ${result.totalCount} записей')),
  //                         );
  //                       }
  //                     },
  //                     icon: gfService.isSyncing
  //                         ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
  //                         : const Icon(Icons.sync, size: 18),
  //                     label: Text(gfService.isSyncing ? 'Синхронизация...' : 'Синхронизировать'),
  //                   ),
  //                 ),
  //               ],
  //               if (gfService.lastError != null) ...[
  //                 const SizedBox(height: 8),
  //                 Text(gfService.lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
  //               ],
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildAutoDetectSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Авто-определение', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Автоматически рассчитать VO2max и FTP из данных Health Connect',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _runAutoDetect(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Запустить авто-определение'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAutoDetect(BuildContext context) async {
    final settings = _settings;
    final healthService = serviceLocator<HealthService>();
    final metricsService = TrainingMetricsService.instance;

    // Auto-detect VO2max from resting HR
    int restingHr = settings.userRestingHeartRate;
    if (restingHr <= 0) {
      for (final r in healthService.sleepRecords) {
        if (r.restHeartRate != null && r.restHeartRate! > 0) {
          restingHr = r.restHeartRate!;
          break;
        }
      }
    }
    if (restingHr > 0) {
      final maxHr = settings.userMaxHeartRate;
      final age = settings.userAge ?? 25;
      final vo2max = Vo2MaxCalculator.estimateFromHeartRate(
        restingHr: restingHr, maxHr: maxHr, age: age);
      if (vo2max > 0) {
        await settings.setUserVo2max(vo2max);
        _vo2maxController.text = vo2max.toStringAsFixed(1);
      }
    }

    // Auto-detect FTP from cycling activities
    final allActs = await LocalActivityRepository.instance.getActivities();
    final cyclingActs = allActs.where((a) => a.kind.name.contains('cycling')).toList();
    final ftp = await metricsService.detectFtp(cyclingActs);
    if (ftp != null && ftp > 0) {
      await settings.setUserFtp(ftp);
      _ftpController.text = ftp.toStringAsFixed(0);
    } else {
      // Fallback: estimate FTP indirectly from running data
      final runningActs = allActs.where((a) =>
          a.kind.name.contains('running') || a.kind.name.contains('jogging')).toList();
      final indirectFtp = metricsService.detectFtpIndirect(runningActs, weightKg: settings.userWeight);
      if (indirectFtp != null && indirectFtp > 0) {
        await settings.setUserFtp(indirectFtp);
        _ftpController.text = indirectFtp.toStringAsFixed(0);
      }
    }

    // Auto-detect Threshold Pace from running activities
    final runningActs = allActs.where((a) =>
        a.kind.name.contains('running') || a.kind.name.contains('jogging')).toList();
    final thresholdPace = metricsService.detectThresholdPace(runningActs);
    if (thresholdPace != null && thresholdPace > 0) {
      final paceMin = (thresholdPace * 60).toInt();
      final paceSec = ((thresholdPace * 60) % 60).round();
      debugPrint('Detected threshold pace: $paceMin:${paceSec.toString().padLeft(2, '0')} /km');
    }

    // Auto-detect LTHR from any activities with HR
    final lthr = metricsService.detectLthr(allActs);
    if (lthr != null && lthr > 0) {
      debugPrint('Detected LTHR: $lthr bpm');
    }

    if (mounted) {
      final ftpText = _ftpController.text.isNotEmpty ? 'FTP: ${_ftpController.text} Вт' : 'FTP: нет данных';
      final method = cyclingActs.isNotEmpty ? '(power meter)' : '(косвенный расчёт)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('VO2max: ${_vo2maxController.text}, $ftpText $method'),
        backgroundColor: Colors.green,
      ));
    }
  }
}
