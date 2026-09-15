import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:zapfit/core/constants/map_constants.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/utils/body_composition_calculator.dart';
import 'package:zapfit/core/utils/body_fat_calculator.dart';
import 'package:zapfit/core/utils/bsa_calculator.dart';
import 'package:zapfit/core/utils/ideal_weight_calculator.dart';
import 'package:zapfit/core/utils/pmr_calculator.dart';
import 'package:zapfit/core/utils/fitness_age_calculator.dart';
import 'package:zapfit/core/utils/life_expectancy_calculator.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String? userName;
  final String? userPhotoUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userPhotoUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  String? _name;
  String? _photoUrl;
  List<ActivityRecord> _activities = [];
  bool _isLoading = true;
  String? _error;

  // Follow state: null = unknown, 0 = not following, 1 = pending (I sent), 2 = accepted, 3 = they follow me (pending I need to accept)
  int? _followState;
  bool _followLoading = false;
  bool _isSelf = false;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _photoUrl = widget.userPhotoUrl;
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        _loadProfile(),
        _loadActivities(),
        _loadFollowStatus(),
      ]);
    } catch (e) {
      debugPrint('_load error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final userRes = await _apiClient.get('/api/v1/users/id/${widget.userId}');
      if (userRes.statusCode == 200) {
        final data = json.decode(userRes.body) as Map<String, dynamic>;
        _name = data['name']?.toString() ?? data['username']?.toString();
        final photo = data['photo_path']?.toString();
        if (photo != null && photo.isNotEmpty && !photo.startsWith('http')) {
          final serverUrl = await SecureStorageService().read(key: 'server_url');
          final baseUrl = serverUrl != null ? UrlUtils.normalizeBaseUrl(serverUrl) : '';
          final lastSlash = photo.lastIndexOf('/');
          final fileName = lastSlash >= 0 ? photo.substring(lastSlash + 1) : photo;
          _photoUrl = '$baseUrl/user_images/$fileName';
        }
      }
    } catch (_) {}
  }

  Future<void> _loadActivities() async {
    try {
      final actRes = await _apiClient.get('/api/v1/activities/user/${widget.userId}/page_number/1/num_records/50');
      if (actRes.statusCode == 200) {
        final data = json.decode(actRes.body) as List<dynamic>;
        _activities = data.map((item) {
          try {
            return ActivityRecord.fromServerJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<ActivityRecord>().toList();
      }
    } catch (e) {
      _error = 'Ошибка загрузки активностей';
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final userService = serviceLocator<UserService>();
      if (userService.profile == null) await userService.fetchProfile();
      final myId = userService.profile?.id;
      if (myId == null || myId == widget.userId) {
        _isSelf = true;
        return;
      }

      // Check if I follow them
      final myFollowing = await _apiClient.get('/api/v1/followers/user/$myId/targetUser/${widget.userId}');
      if (myFollowing.statusCode == 200 && myFollowing.body != 'null') {
        final data = json.decode(myFollowing.body) as Map<String, dynamic>;
        if (data['is_accepted'] == true) {
          _followState = 2; // accepted
        } else {
          _followState = 1; // pending (I sent)
        }
        return;
      }

      // Check if they follow me
      final theirFollowing = await _apiClient.get('/api/v1/followers/user/${widget.userId}/targetUser/$myId');
      if (theirFollowing.statusCode == 200 && theirFollowing.body != 'null') {
        final data = json.decode(theirFollowing.body) as Map<String, dynamic>;
        if (data['is_accepted'] != true) {
          _followState = 3; // they follow me, pending acceptance
          return;
        }
      }

      _followState = 0; // not following
    } catch (_) {
      _followState = 0;
    }
  }

  Future<void> _sendFollowRequest() async {
    setState(() => _followLoading = true);
    try {
      final res = await _apiClient.post('/api/v1/followers/create/targetUser/${widget.userId}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        _followState = 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запрос на подписку отправлен'), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _followLoading = false);
  }

  Future<void> _acceptFollowRequest() async {
    setState(() => _followLoading = true);
    try {
      final res = await _apiClient.put('/api/v1/followers/accept/targetUser/${widget.userId}');
      if (res.statusCode == 200 || res.statusCode == 204) {
        _followState = 2;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Подписка принята'), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _followLoading = false);
  }

  Future<void> _unfollow() async {
    setState(() => _followLoading = true);
    try {
      final res = await _apiClient.delete('/api/v1/followers/delete/following/targetUser/${widget.userId}');
      if (res.statusCode == 200 || res.statusCode == 204) {
        _followState = 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы отписались'), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _followLoading = false);
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}ч ${m}м';
    return '${m}м';
  }

  IconData _getIconForKind(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.run:
      case ActivityKind.trailRun:
      case ActivityKind.trackRun:
      case ActivityKind.treadmillRun:
      case ActivityKind.virtualRun:
        return Icons.directions_run;
      case ActivityKind.roadCycling:
      case ActivityKind.gravelCycling:
      case ActivityKind.mtbCycling:
      case ActivityKind.commutingCycling:
      case ActivityKind.mixedSurfaceCycling:
      case ActivityKind.virtualCycling:
      case ActivityKind.indoorCycling:
      case ActivityKind.eBikeCycling:
      case ActivityKind.eBikeMountainCycling:
        return Icons.directions_bike;
      case ActivityKind.indoorSwimming:
      case ActivityKind.openWaterSwimming:
        return Icons.pool;
      case ActivityKind.walk:
      case ActivityKind.indoorWalk:
        return Icons.directions_walk;
      case ActivityKind.hike:
        return Icons.terrain;
      case ActivityKind.strengthTraining:
      case ActivityKind.crossfit:
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
  }

  Widget _buildFollowButton(ThemeData theme) {
    if (_followLoading) {
      return const SizedBox(
        width: 200, height: 40,
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    switch (_followState) {
      case 0: // not following
        return FilledButton.icon(
          onPressed: _sendFollowRequest,
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Подписаться'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        );
      case 1: // pending (I sent)
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top, size: 18),
          label: const Text('Ожидает подтверждения'),
        );
      case 2: // accepted
        return OutlinedButton.icon(
          onPressed: _unfollow,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Подписан'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
          ),
        );
      case 3: // they follow me, pending I need to accept
        return FilledButton.icon(
          onPressed: _acceptFollowRequest,
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Принять подписку'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // === ZAPFIT metrics ===
  Widget _zTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _zRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Boer formula for Lean Body Mass (kg)
  double? _boerLbm(double weightKg, double heightCm, bool male) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    return male
        ? 0.407 * weightKg + 0.267 * heightCm - 19.2
        : 0.252 * weightKg + 0.473 * heightCm - 48.3;
  }

  Widget _buildZapfitMetricsCard(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;
    final h = settings.userHeight;
    final w = settings.userWeight;
    final male = settings.userGender == 'male';
    final age = settings.userAge;

    if (h <= 0 || w <= 0) {
      return Card(
        elevation: 0,
        color: Colors.amber.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withOpacity(0.3)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(height: 8),
              Text(
                'Укажите рост и вес в профиле для расчёта метрик ZAPFIT',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final bmi = w / ((h / 100) * (h / 100));
    final bmiPrime = bmi / 25;
    final ponderal = w / ((h / 100) * (h / 100) * (h / 100)); // kg/m³

    BodyCompositionResult? composition;
    if (age != null && age >= 6) {
      composition = BodyCompositionCalculator.calculate(
        weightKg: w,
        heightCm: h,
        age: age,
        gender: male ? 1 : 0,
      );
    }
    final bodyFatEst = composition?.bodyFatPercentage;

    final bmrMifflin = (age != null)
        ? PmrCalculator.mifflin(weightKg: w, heightCm: h, age: age, male: male).round().toString()
        : 'Нет данных';
    final bmrHarris = (age != null)
        ? PmrCalculator.harrisBenedict(weightKg: w, heightCm: h, age: age, male: male).round().toString()
        : 'Нет данных';
    final bmrKatch = (bodyFatEst != null && bodyFatEst > 0)
        ? PmrCalculator.katchMcArdle(weightKg: w, bodyFatPercent: bodyFatEst).round().toString()
        : 'Нет данных';

    final bsa = BsaCalculator.mosteller(h, w);

    final devine = IdealWeightCalculator.devine(h, male);
    final robinson = IdealWeightCalculator.robinson(h, male);
    final miller = IdealWeightCalculator.miller(h, male);

    final waist = settings.userWaistCm;
    final hip = settings.userHipCm;
    final neck = settings.userNeckCm;
    final navy = BodyFatCalculator.navy(
      heightCm: h,
      waistCm: waist,
      neckCm: neck,
      hipCm: hip,
      male: male,
    );
    final ymca = BodyFatCalculator.ymca(weightKg: w, waistCm: waist, male: male);
    final whr = BodyFatCalculator.whr(waistCm: waist, hipCm: hip);
    final whtr = BodyFatCalculator.whtr(waistCm: waist, heightCm: h);

    final lbm = _boerLbm(w, h, male);

    final fitnessAge = (age != null && settings.userVo2max > 0)
        ? FitnessAgeCalculator.estimate(
            vo2max: settings.userVo2max,
            chronologicalAge: age,
            male: male,
          ).toString()
        : 'Нет данных';

    final lifeExp = (age != null)
        ? LifeExpectancyCalculator.estimate(
            ageYears: age,
            male: male,
            vo2max: settings.userVo2max > 0 ? settings.userVo2max : null,
            restingHr: settings.userRestingHeartRate,
          ).toStringAsFixed(1)
        : 'Нет данных';

    String tanaka = 'Нет данных';
    String fox = 'Нет данных';
    String oakland = 'Нет данных';
    String gellish = 'Нет данных';
    if (age != null) {
      tanaka = (208 - 0.7 * age).round().toString();
      fox = (220 - age).round().toString();
      oakland = (211 - 0.64 * age).round().toString();
      gellish = (207 - 0.7 * age).round().toString();
    }

    final ftp = settings.userFtp > 0 ? '${settings.userFtp.round()} Вт' : 'Нет данных';
    final vo2 = settings.userVo2max > 0 ? settings.userVo2max.toStringAsFixed(1) : 'Нет данных';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Метрики ZAPFIT',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            _zTitle('Антропометрия'),
            _zRow('ИМТ', '${bmi.toStringAsFixed(1)}'),
            _zRow('ИМТ Prime', bmiPrime.toStringAsFixed(2)),
            _zRow('Индекс Пондераля', '${ponderal.toStringAsFixed(1)} кг/м³'),
            _zRow('Площадь тела (BSA, Mosteller)', '${bsa.toStringAsFixed(2)} м²'),
            _zTitle('Метаболизм'),
            _zRow('BMR (Mifflin-St Jeor)', '$bmrMifflin ккал'),
            _zRow('BMR (Harris-Benedict)', '$bmrHarris ккал'),
            _zRow('BMR (Katch-McArdle)', '$bmrKatch ккал'),
            _zRow('TDEE', 'Нет данных'),
            _zTitle('Состав тела'),
            _zRow('Безжировая масса (LBM, Boer)', lbm != null ? '${lbm.toStringAsFixed(1)} кг' : 'Нет данных'),
            _zRow('Жир тела (оценка, Deurenberg)', bodyFatEst != null ? '${bodyFatEst.toStringAsFixed(1)}%' : 'Нет данных'),
            _zRow('Жир тела (Navy)',
                navy != null ? '${navy.toStringAsFixed(1)}% — ${BodyFatCalculator.classify(navy, male: male)}' : 'Нет данных'),
            _zRow('Жир тела (YMCA)',
                ymca != null ? '${ymca.toStringAsFixed(1)}% — ${BodyFatCalculator.classify(ymca, male: male)}' : 'Нет данных'),
            _zRow('WHR (талия/бёдра)',
                whr != null ? '${whr.toStringAsFixed(2)} — ${BodyFatCalculator.classifyWhr(whr, male: male)}' : 'Нет данных'),
            _zRow('WHtR (талия/рост)',
                whtr != null ? '${whtr.toStringAsFixed(2)} — ${BodyFatCalculator.classifyWhtr(whtr)}' : 'Нет данных'),
            _zTitle('Идеальный вес'),
            _zRow('Devine', '${devine.toStringAsFixed(1)} кг'),
            _zRow('Robinson', '${robinson.toStringAsFixed(1)} кг'),
            _zRow('Miller', '${miller.toStringAsFixed(1)} кг'),
            _zTitle('Возраст и здоровье'),
            _zRow('Физический возраст', fitnessAge),
            _zRow('Сердечный возраст', 'Нет данных'),
            _zRow('Ожидаемая продолжительность (остаток)', lifeExp),
            _zTitle('Авто-пороги'),
            _zRow('FTP', ftp),
            _zRow('VO2max', vo2),
            _zRow('LTHR', 'Нет данных'),
            _zRow('Пороговый темп', 'Нет данных'),
            _zRow('Размер костей (frame size)', 'Нет данных'),
            _zTitle('Макс. ЧСС (формулы)'),
            _zRow('Танака (208 − 0.7·возраст)', tanaka),
            _zRow('Fox (220 − возраст)', fox),
            _zRow('Oakland (211 − 0.64·возраст)', oakland),
            _zRow('Gellish (207 − 0.7·возраст)', gellish),
            _zRow('Установленный max HR', '${settings.userMaxHeartRate}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_name ?? 'Профиль'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        if (_photoUrl != null && _photoUrl!.isNotEmpty)
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            child: ClipOval(
                              child: SecureImage(
                                imageUrl: _photoUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              _name?.isNotEmpty == true ? _name![0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 36,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          _name ?? 'Пользователь',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_activities.length} активностей',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 16),
                        if (!_isSelf && _followState != null)
                          _buildFollowButton(theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // === ZAPFIT metrics ===
                  if (_isSelf) _buildZapfitMetricsCard(context),
                  if (_isSelf) const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_activities.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Нет активностей',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    )
                  else
                    ..._activities.map((act) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityDetailScreen(
                              activity: act,
                              isOwnActivity: false,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _getIconForKind(act.kind),
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      act.title ?? 'Активность',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      DateFormat('dd MMMM, HH:mm').format(act.startedAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (act.distanceMeters > 0)
                                    Text(
                                      '${(act.distanceMeters / 1000).toStringAsFixed(1)} км',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  if (act.durationSeconds > 0)
                                    Text(
                                      _formatDuration(act.durationSeconds),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
    );
  }
}
