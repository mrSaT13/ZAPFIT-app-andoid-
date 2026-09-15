import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:zapfit/features/feed/user_profile_screen.dart';

class PeopleSearchScreen extends StatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  State<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends State<PeopleSearchScreen> {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<_UserResult> _results = [];
  bool _isLoading = false;
  bool _searched = false;
  Timer? _debounce;

  // Cache for local filtering fallback
  List<Map<String, dynamic>>? _allUsersCache;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() { _isLoading = true; _searched = true; });

    final myId = _getMyUserId();

    // Try the contains endpoint first (server v19+)
    try {
      final res = await _apiClient.get(
        '/api/v1/users/username/contains/${Uri.encodeComponent(q)}',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          _results = _parseUsers(data, myId);
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
      // If 404 or 422 — server doesn't have this endpoint, fall back
      debugPrint('PeopleSearch: contains endpoint returned ${res.statusCode}, falling back');
    } catch (e) {
      debugPrint('PeopleSearch: contains endpoint error: $e, falling back');
    }

    // Fallback: fetch all users and filter locally
    await _searchFallback(q, myId);
  }

  Future<void> _searchFallback(String query, int? myId) async {
    try {
      // Load cache if empty
      if (_allUsersCache == null || _allUsersCache!.isEmpty) {
        final res = await _apiClient.get('/api/v1/users/page_number/1/num_records/500');
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data is Map<String, dynamic> && data.containsKey('records')) {
            _allUsersCache = (data['records'] as List).cast<Map<String, dynamic>>();
          } else if (data is List) {
            _allUsersCache = data.cast<Map<String, dynamic>>();
          }
        }
      }

      if (_allUsersCache != null) {
        final lq = query.toLowerCase();
        _results = _allUsersCache!
            .where((u) {
              final name = (u['name']?.toString() ?? '').toLowerCase();
              final username = (u['username']?.toString() ?? '').toLowerCase();
              return name.contains(lq) || username.contains(lq);
            })
            .map((u) => _parseSingleUser(u, myId))
            .where((u) => u != null && !u.isMe)
            .cast<_UserResult>()
            .toList();
      } else {
        _results = [];
      }
    } catch (e) {
      debugPrint('PeopleSearch: fallback error: $e');
      _results = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<_UserResult> _parseUsers(List<dynamic> data, int? myId) {
    return data.map((item) => _parseSingleUser(item as Map<String, dynamic>, myId))
        .whereType<_UserResult>()
        .where((u) => !u.isMe)
        .toList();
  }

  _UserResult? _parseSingleUser(Map<String, dynamic> map, int? myId) {
    final id = map['id'] as int?;
    if (id == null) return null;
    final name = map['name']?.toString() ?? map['username']?.toString() ?? '';
    final username = map['username']?.toString() ?? '';
    final photo = map['photo_path']?.toString();
    String? photoUrl;
    if (photo != null && photo.isNotEmpty && !photo.startsWith('http')) {
      final lastSlash = photo.lastIndexOf('/');
      final fileName = lastSlash >= 0 ? photo.substring(lastSlash + 1) : photo;
      photoUrl = '/user_images/$fileName';
    }
    return _UserResult(
      id: id, name: name, username: username,
      photoUrl: photoUrl, isMe: id == myId,
    );
  }

  int? _getMyUserId() {
    try {
      final userService = serviceLocator<UserService>();
      return userService.profile?.id;
    } catch (_) {}
    return null;
  }

  Future<String?> _buildPhotoUrl(String? photo) async {
    if (photo == null || photo.isEmpty) return null;
    if (photo.startsWith('http')) return photo;
    final serverUrl = await SecureStorageService().read(key: 'server_url');
    final baseUrl = serverUrl != null ? UrlUtils.normalizeBaseUrl(serverUrl) : '';
    return '$baseUrl$photo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Найти людей'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Поиск по имени...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _results = []; _searched = false; });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _searched ? 'Никого не нашли' : 'Введите имя пользователя',
                            style: TextStyle(color: theme.colorScheme.outline, fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return FutureBuilder<String?>(
                            future: _buildPhotoUrl(user.photoUrl),
                            builder: (context, snapshot) {
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: snapshot.data != null && snapshot.data!.isNotEmpty
                                      ? ClipOval(
                                          child: SecureImage(
                                            imageUrl: snapshot.data!,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: user.username.isNotEmpty
                                    ? Text('@${user.username}')
                                    : null,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      userId: user.id,
                                      userName: user.name,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserResult {
  final int id;
  final String name;
  final String username;
  final String? photoUrl;
  final bool isMe;

  _UserResult({
    required this.id,
    required this.name,
    required this.username,
    this.photoUrl,
    required this.isMe,
  });
}
