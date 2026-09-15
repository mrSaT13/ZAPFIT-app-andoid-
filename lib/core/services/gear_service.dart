import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/gear_photo_sync_service.dart';

class GearService extends ChangeNotifier {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  
  List<GearRecord> _gears = [];
  List<GearRecord> get gears => _gears;
  
  Map<String, int?> _defaultGears = {};
  Map<String, int?> get defaultGears => _defaultGears;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchGears() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/api/v1/gears');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final records = (data['records'] as List<dynamic>?) ?? <dynamic>[];
        
        final List<GearRecord> baseGears = records.map((item) => GearRecord.fromJson(item as Map<String, dynamic>)).toList();
        
        _gears = baseGears;
        notifyListeners();

        for (int i = 0; i < _gears.length; i++) {
          final detail = await fetchGearDetail(_gears[i].id);
          if (detail != null) {
            _gears[i] = GearRecord(
              id: detail.id,
              nickname: detail.nickname,
              brand: detail.brand,
              model: detail.model,
              gearType: detail.gearType,
              totalDistance: detail.totalDistance,
              totalTime: detail.totalTime,
              initialKms: detail.initialKms ?? 0.0,
              active: detail.active,
              purchaseValue: detail.purchaseValue,
              wheelDiameterCm: detail.wheelDiameterCm,
            );
            notifyListeners();
          }
        }
        await fetchDefaultGears();
        // Fire-and-forget sync local gear photos to server
        try {
          await GearPhotoSyncService.instance.syncAll();
        } catch (e) {
          debugPrint('Gear photo sync after fetch: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching gears: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDefaultGears() async {
    try {
      final response = await _apiClient.get('/api/v1/profile/default_gear');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _defaultGears = data.map((key, value) => MapEntry(key, value as int?));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching default gears: $e');
    }
  }

  Future<void> setDefaultGear(String typeKey, int? gearId) async {
    try {
      final updatedDefaults = Map<String, int?>.from(_defaultGears);
      updatedDefaults[typeKey] = gearId;
      
      final response = await _apiClient.put('/api/v1/profile/default_gear', body: updatedDefaults);
      if (response.statusCode == 200) {
        _defaultGears = updatedDefaults;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting default gear: $e');
    }
  }

  Future<void> deleteGear(int id) async {
    try {
      final response = await _apiClient.delete('/api/v1/gears/$id');
      if (response.statusCode == 204) {
        _gears.removeWhere((g) => g.id == id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting gear: $e');
    }
  }

  Future<GearDetail?> fetchGearDetail(int gearId) async {
    try {
      final response = await _apiClient.get('/api/v1/gears/id/$gearId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return GearDetail.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching gear detail: $e');
    }
    return null;
  }

  Future<List<GearImage>> fetchGearImages(int gearId) async {
    try {
      final response = await _apiClient.get('/api/v1/gear_images/gear/$gearId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((e) => GearImage.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching gear images: $e');
    }
    return [];
  }

  Future<bool> deleteGearImage(int imageId) async {
    try {
      final response = await _apiClient.delete('/api/v1/gear_images/$imageId');
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting gear image: $e');
      return false;
    }
  }

  Future<GearRecord?> createGear({
    required String nickname,
    String? brand,
    String? model,
    required int gearType,
    double? initialKms,
    double? purchaseValue,
    double? wheelDiameterCm,
  }) async {
    try {
      final body = <String, dynamic>{
        'nickname': nickname,
        'gear_type': gearType,
      };
      if (brand != null && brand.isNotEmpty) body['brand'] = brand;
      if (model != null && model.isNotEmpty) body['model'] = model;
      if (initialKms != null && initialKms > 0) body['initial_kms'] = initialKms;
      if (purchaseValue != null && purchaseValue > 0) body['purchase_value'] = purchaseValue;
      if (wheelDiameterCm != null && wheelDiameterCm > 0) body['wheel_diameter_cm'] = wheelDiameterCm;

      final response = await _apiClient.post('/api/v1/gears', body: body);
      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final gear = GearRecord.fromJson(data);
        _gears.add(gear);
        notifyListeners();
        return gear;
      }
    } catch (e) {
      debugPrint('Error creating gear: $e');
    }
    return null;
  }

  Future<bool> updateGear(GearDetail gear) async {
    try {
      final body = gear.toJson();
      final response = await _apiClient.put('/api/v1/gears', body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final updated = GearRecord.fromJson(data);
        final idx = _gears.indexWhere((g) => g.id == updated.id);
        if (idx >= 0) _gears[idx] = updated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating gear: $e');
    }
    return false;
  }

  // --- Gear Components ---

  Future<List<GearComponent>> fetchComponents(int gearId) async {
    try {
      final response = await _apiClient.get('/api/v1/gear_components/gear_id/$gearId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((item) => GearComponent.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching components: $e');
    }
    return [];
  }

  Future<GearComponent?> createComponent({
    required int gearId,
    required String type,
    required String brand,
    required String model,
    DateTime? purchaseDate,
    int? expectedKms,
    double? purchaseValue,
  }) async {
    try {
      final body = <String, dynamic>{
        'gear_id': gearId,
        'type': type,
        'brand': brand,
        'model': model,
        'active': true,
      };
      if (purchaseDate != null) body['purchase_date'] = purchaseDate.toIso8601String();
      if (expectedKms != null) body['expected_kms'] = expectedKms;
      if (purchaseValue != null) body['purchase_value'] = purchaseValue;

      final response = await _apiClient.post('/api/v1/gear_components', body: body);
      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return GearComponent.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error creating component: $e');
    }
    return null;
  }

  Future<bool> updateComponent(GearComponent component) async {
    try {
      final body = component.toJson();
      final response = await _apiClient.put('/api/v1/gear_components', body: body);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating component: $e');
    }
    return false;
  }

  Future<bool> retireComponent(GearComponent component) async {
    return updateComponent(component.copyWith(
      active: false,
      retiredDate: DateTime.now(),
    ));
  }

  Future<bool> deleteComponent(int componentId) async {
    try {
      final response = await _apiClient.delete('/api/v1/gear_components/$componentId');
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting component: $e');
    }
    return false;
  }
}
