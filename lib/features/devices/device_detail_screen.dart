import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/coordinators/coordinator_registry.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/xiaomi_ble_auth_service.dart';
import 'package:zapfit/core/services/companion_device_service.dart';
import 'package:zapfit/core/services/auto_reconnect_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:intl/intl.dart';

class DeviceDetailScreen extends StatefulWidget {
  final TrackedDevice device;
  const DeviceDetailScreen({super.key, required this.device});
  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> with SingleTickerProviderStateMixin {
  final BluetoothSensorService _bleService = serviceLocator<BluetoothSensorService>();
  final HealthService _healthService = serviceLocator<HealthService>();
  int _currentHeartRate = 0;
  int _currentCadence = 0;
  double _currentPower = 0;
  int _batteryLevel = 0;
  StreamSubscription<int>? _hrSub;
  StreamSubscription<int>? _cadenceSub;
  StreamSubscription<double>? _powerSub;
  StreamSubscription<int>? _batterySub;
  bool _showBondHelp = false;
  bool _isAuthenticating = false;
  String? _authStatus;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _bleService.addListener(_onBleChanged);
    _subscribeToStreams();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _subscribeToStreams() {
    _hrSub = _bleService.heartRate.listen((hr) { if (mounted) setState(() => _currentHeartRate = hr); });
    _cadenceSub = _bleService.cadence.listen((c) { if (mounted) setState(() => _currentCadence = c); });
    _powerSub = _bleService.power.listen((p) { if (mounted) setState(() => _currentPower = p); });
    _batterySub = _bleService.battery.listen((b) { if (mounted) setState(() => _batteryLevel = b); });
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleChanged);
    _hrSub?.cancel(); _cadenceSub?.cancel(); _powerSub?.cancel(); _batterySub?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _onBleChanged() { if (mounted) setState(() {}); }

  TrackedDevice get _device => _bleService.trackedDevices.firstWhere((d) => d.id == widget.device.id, orElse: () => widget.device);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = _device;
    final isConnected = _bleService.isDeviceConnected(device.id);
    return Scaffold(body: isConnected ? _buildConnectedView(device, theme) : _buildDisconnectedView(device, theme));
  }

  // === DISCONNECTED VIEW ===
  Widget _buildDisconnectedView(TrackedDevice device, ThemeData theme) {
    return CustomScrollView(slivers: [
      SliverAppBar(expandedHeight: 200, pinned: true, flexibleSpace: FlexibleSpaceBar(
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        background: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary, theme.colorScheme.tertiary])),
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 16),
            Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
              child: Icon(_getDeviceIcon(device), size: 40, color: Colors.white)),
          ])),
        ),
      )),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _buildStatusRow(icon: Icons.bluetooth, label: 'Статус', value: 'Отключено', valueColor: Colors.grey),
          const Divider(height: 24),
          _buildStatusRow(icon: Icons.category_outlined, label: 'Тип', value: device.categoryLabel),
          if (device.brandLabel.isNotEmpty) ...[const Divider(height: 24), _buildStatusRow(icon: Icons.business, label: 'Бренд', value: device.brandLabel)],
          if (device.lastSeen != null) ...[const Divider(height: 24), _buildStatusRow(icon: Icons.access_time, label: 'Последнее подключение', value: DateFormat('d MMMM yyyy, HH:mm').format(device.lastSeen!))],
        ]))))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
        SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(
          onPressed: _isAuthenticating ? null : () => _connectDevice(device),
          icon: _isAuthenticating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bluetooth, size: 20),
          label: Text(_isAuthenticating ? 'Аутентификация...' : (device.brand == DeviceBrand.xiaomi || device.brand == DeviceBrand.amazfit ? 'Подключить Xiaomi' : 'Подключить')),
        )),
        if (_authStatus != null) ...[const SizedBox(height: 8), Text(_authStatus!, style: TextStyle(fontSize: 12, color: _authStatus!.contains('успешно') || _authStatus!.startsWith('✓') ? Colors.green : Colors.orange))],
      ]))),
      if (device.brand == DeviceBrand.xiaomi || device.brand == DeviceBrand.amazfit) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        if (_showBondHelp) _buildBondHelpCard(device) else TextButton.icon(onPressed: () => setState(() => _showBondHelp = true), icon: const Icon(Icons.help_outline, size: 16), label: const Text('Часы не подключаются?')),
      ]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('ID: ${device.id}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)))))),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }

  // === CONNECTED VIEW ===
  Widget _buildConnectedView(TrackedDevice device, ThemeData theme) {
    return Column(children: [
      Container(padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary, theme.colorScheme.tertiary])),
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
              child: Icon(_getDeviceIcon(device), size: 24, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Подключено${_batteryLevel > 0 ? ' • $_batteryLevel%' : ''}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
            ])),
            IconButton(onPressed: () => _disconnectDevice(device), icon: const Icon(Icons.bluetooth_disabled, color: Colors.white), tooltip: 'Отключить'),
          ])),
          TabBar(controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60, tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Статус'),
            Tab(icon: Icon(Icons.directions_walk, size: 20), text: 'Активность'),
            Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'Пульс'),
            Tab(icon: Icon(Icons.settings_outlined, size: 20), text: 'Настройки'),
          ]),
        ]),
      ),
      Expanded(child: TabBarView(controller: _tabController, children: [
        _buildStatusTab(device), _buildActivityTab(device), _buildHeartRateTab(device), _buildSettingsTab(device),
      ])),
    ]);
  }

  // === TAB: STATUS ===
  Widget _buildStatusTab(TrackedDevice device) {
    final theme = Theme.of(context);
    final isXiaomi = device.brand == DeviceBrand.xiaomi || device.brand == DeviceBrand.amazfit;
    final isAuth = XiaomiBleAuthService.instance.isAuthenticated(device.id);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildInfoCard(theme, 'Подключение', [
        _buildInfoRow(Icons.bluetooth, 'Статус', 'Подключено', Colors.green),
        if (isXiaomi) _buildInfoRow(Icons.lock_outline, 'Авторизация', isAuth ? 'Успешно' : 'Стандартный', isAuth ? Colors.green : Colors.orange),
      ]),
      const SizedBox(height: 12),
      _buildInfoCard(theme, 'Устройство', [
        _buildInfoRow(Icons.category_outlined, 'Тип', device.categoryLabel, null),
        if (device.brandLabel.isNotEmpty) _buildInfoRow(Icons.business, 'Бренд', device.brandLabel, null),
        if (device.firmwareVersion != null) _buildInfoRow(Icons.info_outline, 'Прошивка', device.firmwareVersion!, null),
      ]),
      if (_batteryLevel > 0) ...[const SizedBox(height: 12), _buildInfoCard(theme, 'Батарея', [
        _buildInfoRow(Icons.battery_full, 'Уровень', '$_batteryLevel%', _batteryColor(_batteryLevel)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _batteryLevel / 100, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(_batteryColor(_batteryLevel)), borderRadius: BorderRadius.circular(4)),
      ])],
    ]);
  }

  // === TAB: ACTIVITY ===
  Widget _buildActivityTab(TrackedDevice device) {
    final theme = Theme.of(context);
    final caps = device.capabilities;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Live BLE data
      if (caps['cadence'] == true || _currentCadence > 0)
        _buildMetricCard(theme, Icons.pedal_bike, 'Каденция (BLE)', _currentCadence > 0 ? '$_currentCadence' : '--', 'об/мин', Colors.purple, null),
      if (caps['cadence'] == true || _currentCadence > 0)
        const SizedBox(height: 12),
      if (_currentPower > 0)
        _buildMetricCard(theme, Icons.flash_on, 'Мощность (BLE)', '${_currentPower.round()}', 'Вт', Colors.amber, null),
      if (_currentPower > 0)
        const SizedBox(height: 12),
      // Health Connect synced data
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Данные из Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Шаги, калории и расстояние синхронизируются из Health Connect при нажатии «Синхронизировать».',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () => _syncFromDevice(device), icon: const Icon(Icons.sync, size: 20), label: const Text('Синхронизировать'))),
    ]);
  }

  // === TAB: HEART RATE ===
  Widget _buildHeartRateTab(TrackedDevice device) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(width: 160, height: 160,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _currentHeartRate > 0 ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1), border: Border.all(color: _currentHeartRate > 0 ? Colors.red : Colors.grey, width: 3)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.favorite, color: _currentHeartRate > 0 ? Colors.red : Colors.grey, size: 32),
          const SizedBox(height: 4),
          Text(_currentHeartRate > 0 ? '$_currentHeartRate' : '--', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _currentHeartRate > 0 ? Colors.red : Colors.grey)),
          const Text('уд/мин', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]))),
      const SizedBox(height: 24),
      _buildInfoCard(Theme.of(context), 'Пульс', [
        _buildInfoRow(Icons.favorite, 'Текущий', _currentHeartRate > 0 ? '$_currentHeartRate уд/мин' : 'Нет данных', _currentHeartRate > 0 ? Colors.red : Colors.grey),
      ]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () => _requestHeartRate(device), icon: const Icon(Icons.play_arrow, size: 20), label: const Text('Измерить пульс'))),
    ]);
  }

  // === TAB: SETTINGS ===
  Widget _buildSettingsTab(TrackedDevice device) {
    final theme = Theme.of(context);
    final coordinator = device.coordinatorId != null
        ? CoordinatorRegistry.instance.getById(device.coordinatorId!)
        : null;
    final caps = device.capabilities;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Device capabilities card
      _buildInfoCard(theme, 'Возможности устройства', [
        if (caps['heartRate'] == true) _buildInfoRow(Icons.favorite, 'Пульс', 'Поддерживается', Colors.red),
        if (caps['steps'] == true) _buildInfoRow(Icons.directions_walk, 'Шаги', 'Поддерживается', Colors.green),
        if (caps['sleep'] == true) _buildInfoRow(Icons.bedtime, 'Сон', 'Поддерживается', Colors.blue),
        if (caps['dataFetch'] == true) _buildInfoRow(Icons.sync, 'Синхронизация данных', 'Поддерживается', Colors.purple),
        if (caps['findDevice'] == true) _buildInfoRow(Icons.find_replace, 'Поиск устройства', 'Поддерживается', Colors.orange),
        if (caps['alarms'] == true) _buildInfoRow(Icons.alarm, 'Будильники', 'Поддерживается', Colors.teal),
        if (caps['weather'] == true) _buildInfoRow(Icons.cloud, 'Погода', 'Поддерживается', Colors.blue),
        if (caps['music'] == true) _buildInfoRow(Icons.music_note, 'Музыка', 'Поддерживается', Colors.pink),
        if (caps['stress'] == true) _buildInfoRow(Icons.psychology, 'Стресс', 'Поддерживается', Colors.amber),
        if (caps['spo2'] == true) _buildInfoRow(Icons.air, 'SpO2', 'Поддерживается', Colors.cyan),
        if (caps['temperature'] == true) _buildInfoRow(Icons.thermostat, 'Температура', 'Поддерживается', Colors.deepOrange),
      ]),
      const SizedBox(height: 12),

      // Actions card
      _buildInfoCard(theme, 'Управление', [
        if (caps['findDevice'] == true)
          _buildSettingsTile(Icons.find_replace, 'Найти устройство', 'Заставить вибрировать', () => _findDevice(device)),
        if (caps['alarms'] == true)
          _buildSettingsTile(Icons.alarm, 'Будильники', '${coordinator?.alarmSlotCount ?? 0} слотов', () => _showAlarmsSettings(device)),
        _buildSettingsTile(Icons.notifications_active, 'Уведомления', 'Настройка уведомлений', () => _showNotificationSettings(device)),
      ]),
      const SizedBox(height: 12),

      // Health card
      _buildInfoCard(theme, 'Здоровье', [
        if (caps['heartRate'] == true)
          _buildInfoRow(Icons.favorite, 'Пульс', _currentHeartRate > 0 ? '$_currentHeartRate уд/мин (активен)' : 'Ожидание данных...', _currentHeartRate > 0 ? Colors.red : Colors.grey),
        if (caps['steps'] == true)
          _buildInfoRow(Icons.directions_walk, 'Шаги', 'Синхронизация через Health Connect', Colors.green),
        if (caps['sleep'] == true)
          _buildInfoRow(Icons.bedtime, 'Сон', 'Синхронизация через Health Connect', Colors.blue),
        if (caps['stress'] == true)
          _buildInfoRow(Icons.psychology, 'Стресс', 'Синхронизация через Health Connect', Colors.amber),
        if (caps['spo2'] == true)
          _buildInfoRow(Icons.air, 'SpO2', 'Синхронизация через Health Connect', Colors.cyan),
        if (caps['temperature'] == true)
          _buildInfoRow(Icons.thermostat, 'Температура', 'Синхронизация через Health Connect', Colors.deepOrange),
        if (caps.values.every((v) => v != true))
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Данные о здоровье синхронизируются через Health Connect. Нажмите «Синхронизировать» на вкладке «Активность».',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ]),
      const SizedBox(height: 12),

      // Device-specific settings from coordinator
      if (coordinator != null) ...[
        for (final group in coordinator.getDeviceSettings(device.id))
          ...[
            _buildInfoCard(theme, group.title, group.settings.map((setting) =>
              _buildSettingsTile(
                _getSettingIcon(setting.key),
                setting.label,
                _formatSettingValue(setting, device),
                () => _showSettingDialog(device, setting),
              ),
            ).toList()),
            const SizedBox(height: 12),
          ],
      ],

      // Companion device section
      _buildInfoCard(theme, 'Привязка', [
        _buildInfoRow(Icons.link, 'CompanionDevice', 'Android 12+', Colors.green),
        const SizedBox(height: 8),
        Text(
          'CompanionDeviceManager обеспечивает стабильное подключение '
          'и автоматическое переподключение при разрывах.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ]),
      const SizedBox(height: 12),

      // Danger zone
      if (device.brand == DeviceBrand.xiaomi || device.brand == DeviceBrand.amazfit)
        SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
          onPressed: () => _removeBond(device),
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          label: const Text('Сбросить привязку', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        )),
    ]);
  }

  // === SHARED WIDGETS ===
  Widget _buildInfoCard(ThemeData theme, String title, List<Widget> children) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 1)),
        const SizedBox(height: 12), ...children,
      ])));
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color? valueColor) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey), const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor, fontSize: 14)),
    ]));
  }

  Widget _buildMetricCard(ThemeData theme, IconData icon, String label, String value, String unit, Color color, VoidCallback? onTap) {
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3))),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
      ]))));
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return ListTile(leading: Icon(icon, size: 22), title: Text(title, style: const TextStyle(fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, size: 20) : null, onTap: onTap, contentPadding: EdgeInsets.zero);
  }

  Widget _buildStatusRow({required IconData icon, required String label, required String value, Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? theme.colorScheme.onSurface)),
    ]);
  }

  Widget _buildBondHelpCard(TrackedDevice device) {
    return Card(color: Colors.amber.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.withOpacity(0.3))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.warning_amber, color: Colors.amber, size: 20), const SizedBox(width: 8),
          Expanded(child: Text('Amazfit/Xiaomi: отвяжите от Mi Fit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))]),
        const SizedBox(height: 12),
        Text('1. Mi Fit → Профиль → Мои устройства → ${device.name} → Отвязать\n'
          '2. Настройки BT → ${device.name} → Забыть\n'
          '3. Вернитесь сюда → Подключить', style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _removeBond(device), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Сбросить'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => _openBluetoothSettings(), icon: const Icon(Icons.settings_bluetooth, size: 16), label: const Text('BT настройки'))),
        ]),
      ])));
  }

  Color _batteryColor(int level) => level > 50 ? Colors.green : level > 20 ? Colors.orange : Colors.red;

  IconData _getDeviceIcon(TrackedDevice device) {
    switch (device.category) {
      case DeviceCategory.smartWatch: return Icons.watch;
      case DeviceCategory.smartBand: return Icons.watch;
      case DeviceCategory.heartRateMonitor: return Icons.favorite;
      case DeviceCategory.cyclingSensor: return Icons.pedal_bike;
      case DeviceCategory.smartScale: return Icons.monitor_weight;
      default: return Icons.bluetooth;
    }
  }

  IconData _getSettingIcon(String key) {
    if (key.contains('wear')) return Icons.checkroom;
    if (key.contains('hr') || key.contains('heart')) return Icons.favorite;
    if (key.contains('vibration')) return Icons.vibration;
    if (key.contains('alarm')) return Icons.alarm;
    if (key.contains('dnd') || key.contains('disturb')) return Icons.do_not_disturb;
    if (key.contains('display') || key.contains('screen')) return Icons.phone_android;
    if (key.contains('notification')) return Icons.notifications;
    if (key.contains('fitness') || key.contains('goal')) return Icons.directions_walk;
    if (key.contains('weather')) return Icons.cloud;
    if (key.contains('raise') || key.contains('wake')) return Icons.waving_hand;
    if (key.contains('always_on') || key.contains('aod')) return Icons.light_mode;
    return Icons.settings;
  }

  String _formatSettingValue(DeviceSetting setting, TrackedDevice device) {
    if (setting.type == DeviceSettingType.toggle) {
      return (setting.defaultValue as bool?) ?? false ? 'Вкл' : 'Выкл';
    }
    if (setting.type == DeviceSettingType.dropdown && setting.options != null && setting.options!.isNotEmpty) {
      final opt = setting.options!.firstWhere(
        (DeviceSettingOption o) => o.value == setting.defaultValue,
        orElse: () => setting.options!.first,
      );
      return opt.label;
    }
    return '${setting.defaultValue ?? ''}${setting.unit != null ? ' ${setting.unit}' : ''}';
  }

  void _showSettingDialog(TrackedDevice device, DeviceSetting setting) {
    // TODO: Implement setting dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Настройка "${setting.label}" будет доступна скоро')),
    );
  }

  void _showAlarmsSettings(TrackedDevice device) {
    // TODO: Implement alarms settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройка будильников будет доступна скоро')),
    );
  }

  void _showNotificationSettings(TrackedDevice device) {
    // TODO: Implement notification settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройка уведомлений будет доступна скоро')),
    );
  }

  // === ACTIONS ===
  /// Connect: try Xiaomi auth first, fall back to standard BLE if it fails
  Future<void> _connectDevice(TrackedDevice device) async {
    if (_isAuthenticating) {
      debugPrint('CONNECT: Already connecting, ignoring...');
      return;
    }
    final isXiaomi = device.brand == DeviceBrand.xiaomi || device.brand == DeviceBrand.amazfit;
    setState(() { _isAuthenticating = true; _authStatus = null; });
    debugPrint('=== CONNECT: ${device.name} (${device.id}) ===');

    try {
      final btDevice = BluetoothDevice.fromId(device.id);

      // On Android 12+, try CompanionDeviceManager association first
      final isAvailable = await CompanionDeviceService.instance.isAvailable();
      if (isAvailable) {
        setState(() => _authStatus = 'CompanionDevice pairing...');
        final pairResult = await CompanionDeviceService.instance.pairDevice(
          macAddress: device.id,
          deviceName: device.name,
        );
        if (pairResult != null && pairResult.success) {
          debugPrint('CONNECT: CompanionDevice pairing succeeded');
        }
      }

      if (isXiaomi) {
        // Step 1: Try native Xiaomi auth first
        setState(() => _authStatus = 'Xiaomi auth...');
        debugPrint('CONNECT: Trying Xiaomi auth...');
        final authResult = await XiaomiBleAuthService.instance.authenticate(btDevice);
        debugPrint('CONNECT: Xiaomi auth: ${authResult.isSuccess} - ${authResult.message}');

        if (authResult.isSuccess) {
          setState(() => _authStatus = '✓ ${authResult.message}');
          debugPrint('CONNECT: Auth OK, GATT stays open for standard services');
        } else {
          debugPrint('CONNECT: Auth failed (${authResult.message}), fallback to standard BLE');
          setState(() => _authStatus = 'Auth failed. Connecting as HR monitor...');

          try {
            final platform = MethodChannel('com.zapfit/xiaomi_auth');
            await platform.invokeMethod('disconnect');
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 800));

          try { await _bleService.disconnect(btDevice); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 500));

          await _bleService.connect(btDevice);
          setState(() => _authStatus = '✓ Connected as HR monitor');
        }
      } else {
        setState(() => _authStatus = 'Connecting...');
        await _bleService.connect(btDevice);
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${device.name} connected!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      setState(() { _authStatus = 'Error: $e'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally { setState(() => _isAuthenticating = false); }
  }

  void _syncFromDevice(TrackedDevice device) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Синхронизация с ${device.name}...'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    _healthService.autoImportFromHealthConnect(daysBack: 7).then((_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Готово'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); });
  }

  void _findDevice(TrackedDevice device) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Поиск ${device.name}... вибрация!'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  void _requestHeartRate(TrackedDevice device) async {
    // Try to re-subscribe to HR notifications
    try {
      final bluetoothDevice = BluetoothDevice.fromId(device.id);
      final services = await bluetoothDevice.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid('180D')) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid('2A37') && char.properties.notify) {
              await char.setNotifyValue(true);
              break;
            }
          }
          break;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ожидание данных с пульсометра...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка запроса пульса: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _disconnectDevice(TrackedDevice device) async {
    await _bleService.disconnect(BluetoothDevice.fromId(device.id));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${device.name} отключено'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _removeBond(TrackedDevice device) async {
    try {
      const platform = MethodChannel('com.zapfit/storage');
      final success = await platform.invokeMethod('removeBluetoothBond', {'macAddress': device.id});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success == true ? 'Привязка сброшена' : 'Не удалось'), backgroundColor: success == true ? Colors.green : Colors.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }
  }

  Future<void> _openBluetoothSettings() async {
    try { const platform = MethodChannel('com.zapfit/storage'); await platform.invokeMethod('openBluetoothSettings'); } catch (_) {}
  }
}
