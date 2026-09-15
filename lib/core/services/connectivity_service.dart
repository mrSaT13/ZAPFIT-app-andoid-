import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Колбэк при восстановлении сети
  VoidCallback? onReconnect;

  Future<void> init() async {
    // Проверяем текущее состояние
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    // Слушаем изменения
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        debugPrint('ConnectivityService: Сеть восстановлена, запускаю синхронизацию');
        onReconnect?.call();
      } else if (wasOnline && !_isOnline) {
        debugPrint('ConnectivityService: Сеть потеряна');
      }

      notifyListeners();
    });
  }

  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
