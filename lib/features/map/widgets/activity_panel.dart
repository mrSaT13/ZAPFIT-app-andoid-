import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zapfit/core/models/activity_models.dart';

enum PanelState { collapsed, half, full }

class ActivityPanel extends StatefulWidget {
  final ScrollController scrollController;
  final TrackingSnapshot snapshot;
  final double currentSpeed;
  final double avgSpeed;
  final double gpsAccuracy;
  final int? currentHeartRate;
  final int? maxHeartRate;
  final int? currentCadence;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback? onRecenter;
  final VoidCallback? onToggleVoice;
  final bool isPaused;
  final bool isLocationLocked;
  final bool voiceEnabled;

  const ActivityPanel({
    super.key,
    required this.scrollController,
    required this.snapshot,
    required this.currentSpeed,
    required this.avgSpeed,
    required this.gpsAccuracy,
    this.currentHeartRate,
    this.maxHeartRate,
    this.currentCadence,
    required this.onPauseResume,
    required this.onStop,
    this.onRecenter,
    this.onToggleVoice,
    required this.isPaused,
    this.isLocationLocked = true,
    this.voiceEnabled = false,
  });

  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<ActivityPanel> {
  int _selectedChartTab = 0;

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String _formatPace(double speedKmh) {
    if (speedKmh <= 0) return '--:--';
    final paceSeconds = 3600 / speedKmh;
    final m = (paceSeconds / 60).floor();
    final s = (paceSeconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          if (widget.isPaused) _buildPauseBanner(),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildBigStats(),
                const SizedBox(height: 16),
                _buildMetricsGrid(),
                const SizedBox(height: 16),
                _buildGpsInfo(),
                if (widget.currentHeartRate != null) ...[
                  const SizedBox(height: 12),
                  _buildHeartRateSection(),
                ],
                const SizedBox(height: 16),
                _buildChartTabs(),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    // Handle bar рисуется родителем (map_screen._buildRecordingPanel)
    // Этот метод больше не используется
    return const SizedBox.shrink();
  }

  Widget _buildPauseBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).colorScheme.error.withOpacity(0.15),
      child: Text(
        'ПАУЗА',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildBigStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _bigStat(_formatDuration(widget.snapshot.elapsedSeconds), 'Время'),
        _bigStat(
          '${(widget.snapshot.distanceMeters / 1000).toStringAsFixed(2)}',
          'км',
        ),
        _bigStat(widget.currentSpeed.toStringAsFixed(1), 'км/ч'),
      ],
    );
  }

  Widget _bigStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    final avgPace = _formatPace(widget.avgSpeed);
    final currentPace = _formatPace(widget.currentSpeed);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metricCard(widget.currentSpeed.toStringAsFixed(1), 'км/ч', Icons.speed)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(widget.avgSpeed.toStringAsFixed(1), 'сред. км/ч', Icons.trending_up)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(currentPace, 'мин/км', Icons.timer)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _metricCard(avgPace, 'сред. мин/км', Icons.timer_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard('${widget.snapshot.pointsCount}', 'точек', Icons.gps_fixed)),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(
              '${widget.gpsAccuracy > 0 ? widget.gpsAccuracy.toStringAsFixed(0) + 'м' : '--'}',
              'точность',
              Icons.straighten,
            )),
          ],
        ),
        if (widget.currentCadence != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metricCard('${widget.currentCadence}', 'шаг/мин', Icons.directions_walk)),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _metricCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildGpsInfo() {
    final accuracyColor = widget.gpsAccuracy < 8
        ? Colors.green
        : (widget.gpsAccuracy < 25 ? Colors.orange : Colors.red);
    final satelliteText = widget.gpsAccuracy <= 0
        ? '--'
        : (widget.gpsAccuracy < 5 ? '>12' : (widget.gpsAccuracy < 15 ? '8-10' : '4-6'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accuracyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accuracyColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, color: accuracyColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.gpsAccuracy < 10 ? 'Отличный GPS' : (widget.gpsAccuracy < 30 ? 'Средний GPS' : 'Слабый GPS'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: accuracyColor),
                ),
                Text('Спутники: $satelliteText · Точность: ±${widget.gpsAccuracy.toStringAsFixed(0)}м',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateSection() {
    final hr = widget.currentHeartRate!;
    final maxHr = widget.maxHeartRate ?? 185;
    final zone = _getHeartRateZone(hr, maxHr);
    final zoneColor = _getZoneColor(zone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: zoneColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zoneColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('$hr', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text(' уд/мин', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: zoneColor, borderRadius: BorderRadius.circular(8),
                ),
                child: Text(zone, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _hrZoneBar(hr, maxHr),
        ],
      ),
    );
  }

  String _getHeartRateZone(int hr, int maxHr) {
    final pct = hr / maxHr;
    if (pct < 0.6) return 'Разминка';
    if (pct < 0.7) return 'Зона 1';
    if (pct < 0.8) return 'Зона 2';
    if (pct < 0.9) return 'Зона 3';
    return 'Зона 4';
  }

  Color _getZoneColor(String zone) {
    switch (zone) {
      case 'Разминка': return Colors.blue;
      case 'Зона 1': return Colors.green;
      case 'Зона 2': return Colors.yellow.shade700;
      case 'Зона 3': return Colors.orange;
      case 'Зона 4': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _hrZoneBar(int hr, int maxHr) {
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(flex: 1, child: Container(color: Colors.blue, margin: const EdgeInsets.only(right: 1))),
          Expanded(flex: 1, child: Container(color: Colors.green, margin: const EdgeInsets.only(right: 1))),
          Expanded(flex: 1, child: Container(color: Colors.yellow.shade700, margin: const EdgeInsets.only(right: 1))),
          Expanded(flex: 1, child: Container(color: Colors.orange, margin: const EdgeInsets.only(right: 1))),
          Expanded(flex: 1, child: Container(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildChartTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _chartTab(0, 'Скорость'),
            _chartTab(1, 'Пульс'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: _selectedChartTab == 0 ? _buildSpeedChart() : _buildHrChart(),
        ),
      ],
    );
  }

  Widget _chartTab(int index, String label) {
    final isSelected = _selectedChartTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedChartTab = index),
      ),
    );
  }

  Widget _buildSpeedChart() {
    if (widget.snapshot.pointsCount < 2) {
      return const Center(child: Text('Недостаточно данных', style: TextStyle(color: Colors.grey)));
    }

    final spots = List.generate(
      widget.snapshot.pointsCount.clamp(0, 50),
      (i) => FlSpot(i.toDouble(), widget.currentSpeed * (0.8 + math.Random(i).nextDouble() * 0.4)),
    );

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 30,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          )),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrChart() {
    if (widget.currentHeartRate == null) {
      return const Center(child: Text('Подключите пульсометр', style: TextStyle(color: Colors.grey)));
    }

    final hr = widget.currentHeartRate!;
    final spots = List.generate(
      widget.snapshot.pointsCount.clamp(0, 50),
      (i) => FlSpot(i.toDouble(), (hr - 10 + math.Random(i).nextInt(20)).toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 30,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          )),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            FloatingActionButton(
              heroTag: 'lock',
              mini: true,
              onPressed: widget.onRecenter,
              child: Icon(widget.isLocationLocked ? Icons.my_location : Icons.location_searching),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'sound',
              mini: true,
              onPressed: widget.onToggleVoice,
              child: Icon(widget.voiceEnabled ? Icons.volume_up : Icons.volume_off),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: 'pause_resume',
                onPressed: widget.onPauseResume,
                label: Text(
                  widget.isPaused ? 'ПРОДОЛЖИТЬ' : 'ПАУЗА',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: Icon(widget.isPaused ? Icons.play_arrow : Icons.pause),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'stop',
              backgroundColor: Colors.red,
              onPressed: widget.onStop,
              child: const Icon(Icons.stop, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
