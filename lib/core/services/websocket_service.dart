import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/utils/trusted_http_client.dart';
import 'package:zapfit/core/utils/url_utils.dart';

/// WebSocket service for real-time notifications from the Endurain server.
///
/// Flow:
/// 1. POST `/api/v1/ws/ticket` to get a short-lived ticket (30 s TTL)
/// 2. Connect to `wss://<host>/ws?ticket=<ticket>`
/// 3. Listen for JSON messages `{"message": "...", "notification_id": N}`
class WebSocketService extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _disposed = false;
  bool _ticketUnsupported = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming WebSocket messages.
  Stream<Map<String, dynamic>> get notificationStream => _messageController.stream;
  bool get isConnected => _isConnected;

  /// Obtain a ticket then open the WebSocket connection.
  Future<void> connect() async {
    if (_disposed || _ticketUnsupported) return;
    await disconnect();

    try {
      final serverUrl = await _storage.getServerUrl();
      if (serverUrl == null || serverUrl.isEmpty) return;

      final ticket = await _requestTicket(serverUrl);
      if (ticket == null) {
        debugPrint('WebSocketService: failed to obtain ticket');
        _scheduleReconnect();
        return;
      }

      final baseUrl = UrlUtils.normalizeBaseUrl(serverUrl);
      final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
      final host = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
      final wsUrl = Uri.parse('$wsScheme://$host/ws?ticket=$ticket');

      // Use custom HttpClient that trusts self-signed certificates
      final ioClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      final socket = await WebSocket.connect(
        wsUrl.toString(),
        customClient: ioClient,
      );
      _channel = IOWebSocketChannel(socket);
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
      );

      _isConnected = true;
      notifyListeners();
      _startHeartbeat();
      debugPrint('WebSocketService: connected to $wsUrl');
    } catch (e) {
      debugPrint('WebSocketService: connect error: $e');
      _scheduleReconnect();
    }
  }

  Future<String?> _requestTicket(String serverUrl) async {
    try {
      final url = UrlUtils.buildUrl(serverUrl, '/api/v1/ws/ticket');
      final accessToken = await _storage.getAccessToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Client-Type': 'mobile',
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await trustedHttpClient.post(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['ticket'] as String?;
      }
      debugPrint('WebSocketService: ticket request status ${response.statusCode}');
      if (response.statusCode == 405 || response.statusCode == 404) {
        debugPrint('WebSocketService: server does not support WebSocket tickets, disabling');
        _ticketUnsupported = true;
      }
    } catch (e) {
      debugPrint('WebSocketService: ticket request failed: $e');
    }
    return null;
  }

  void _onMessage(dynamic data) {
    try {
      final message = json.decode(data as String) as Map<String, dynamic>;
      debugPrint('WebSocketService: received: $message');
      _messageController.add(message);
      notifyListeners();
    } catch (e) {
      debugPrint('WebSocketService: parse error: $e');
    }
  }

  void _onDone() {
    debugPrint('WebSocketService: connection closed');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    notifyListeners();
    _scheduleReconnect();
  }

  void _onError(Object error) {
    debugPrint('WebSocketService: error: $error');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    notifyListeners();
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPing();
    });
  }

  void _sendPing() {
    if (_channel == null || !_isConnected) return;
    try {
      _channel!.sink.add(json.encode({'message': 'PING'}));
    } catch (e) {
      debugPrint('WebSocketService: ping failed: $e');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_disposed || _ticketUnsupported) return;
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_disposed && !_isConnected) {
        debugPrint('WebSocketService: reconnecting...');
        connect();
      }
    });
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _isConnected = false;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
