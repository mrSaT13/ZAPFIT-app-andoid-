import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/core/models/gear_replacement.dart';
import 'package:zapfit/core/models/gear_model.dart';

class GearReplacementHistory {
  static final GearReplacementHistory instance = GearReplacementHistory._();
  GearReplacementHistory._();

  List<GearReplacement> _history = [];
  List<GearReplacement> get history => List.unmodifiable(_history);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('gear_replacement_history');
      if (jsonStr != null) {
        final list = json.decode(jsonStr) as List<dynamic>;
        _history = list.map((e) => GearReplacement.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('GearReplacementHistory load error: $e');
      _history = [];
    }
  }

  Future<void> addReplacement(GearComponent oldComponent, String? comment, {double? purchaseValue}) async {
    final replacement = GearReplacement(
      id: DateTime.now().microsecondsSinceEpoch,
      timestamp: DateTime.now(),
      oldComponentType: oldComponent.type,
      oldComponentBrand: oldComponent.brand,
      oldComponentModel: oldComponent.model,
      oldComponentDistance: oldComponent.currentDistance,
      comment: comment?.trim(),
      purchaseValue: purchaseValue,
    );
    _history.insert(0, replacement);
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_history.map((e) => e.toJson()).toList());
      await prefs.setString('gear_replacement_history', jsonStr);
    } catch (e) {
      debugPrint('GearReplacementHistory save error: $e');
    }
  }

  Future<void> clear() async {
    _history = [];
    await _save();
  }
}