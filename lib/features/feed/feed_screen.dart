import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/feed_service.dart';
import 'package:zapfit/core/services/notification_service.dart';
import 'package:zapfit/core/services/connectivity_service.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:zapfit/features/feed/user_profile_screen.dart';
import 'package:zapfit/features/notifications/notifications_screen.dart';
import 'package:zapfit/features/people/people_search_screen.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FeedService _feedService = serviceLocator<FeedService>();
  final NotificationService _notificationService = serviceLocator<NotificationService>();
  final ConnectivityService _connectivity = ConnectivityService.instance;
  StreamSubscription? _activityChangesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();

    _connectivity.onReconnect = () {
      if (mounted) _syncAndRefresh();
    };
    _connectivity.addListener(_onConnectivityChanged);

    // Refresh feed when any activity is edited locally
    _activityChangesSub = LocalActivityRepository.instance.activityChanges.listen((_) {
      if (mounted) _feedService.fetchMyFeed();
    });
  }

  void _onConnectivityChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _syncAndRefresh() async {
    try {
      final syncService = serviceLocator<ActivitySyncService>();
      await syncService.syncAll();
    } catch (_) {}
    _loadAll();
  }

  void _loadAll() {
    _feedService.fetchMyFeed();
    _feedService.fetchFriendsFeed();
    _notificationService.fetchUnreadCount();
    // Подгружаем профиль для фото в ленте
    try {
      final userService = serviceLocator<UserService>();
      if (userService.profile == null) {
        userService.fetchProfile();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _activityChangesSub?.cancel();
    _connectivity.onReconnect = null;
    _connectivity.removeListener(_onConnectivityChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _feedService),
        ChangeNotifierProvider.value(value: _notificationService),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ZAPFIT'),
          centerTitle: true,
          leading: Consumer<NotificationService>(
            builder: (context, ns, _) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute<void>(builder: (context) => const NotificationsScreen())
                  ),
                ),
                if (ns.unreadCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${ns.unreadCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.label,
            tabAlignment: TabAlignment.center,
            isScrollable: false,
            tabs: [
              Tab(text: l10n.feedMyFeed),
              Tab(text: l10n.feedSubscriptions),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Найти людей',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const PeopleSearchScreen()),
              ),
            ),
            IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _FeedList(isMyFeed: true),
            _FeedList(isMyFeed: false),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatefulWidget {
  final bool isMyFeed;
  const _FeedList({required this.isMyFeed});

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final service = serviceLocator<FeedService>();
      if (widget.isMyFeed) {
        service.loadMoreMyFeed();
      } else {
        service.loadMoreFriendsFeed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOnline = ConnectivityService.instance.isOnline;

    return Consumer<FeedService>(
      builder: (context, service, _) {
        final activities = widget.isMyFeed ? service.myFeed : service.friendsFeed;
        final isLoadingMore = widget.isMyFeed ? service.isLoadingMoreMyFeed : service.isLoadingMoreFriends;
        final hasMore = widget.isMyFeed ? service.myFeedHasMore : service.friendsFeedHasMore;

        if (service.isLoading && activities.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (activities.isEmpty && isOnline) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.isMyFeed ? Icons.cloud_queue : Icons.people_outline, size: 64, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  widget.isMyFeed ? l10n.feedEmptyMy : l10n.feedEmptyFriends,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (widget.isMyFeed) await service.fetchMyFeed();
            else await service.fetchFriendsFeed();
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: activities.length + (!isOnline ? 1 : 0) + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (!isOnline && index == 0) {
                return const _OfflineBanner(message: 'Нет сети, показаны локальные активности');
              }
              final activityIndex = !isOnline ? index - 1 : index;
              if (activityIndex >= activities.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _ActivityFeedCard(activity: activities[activityIndex], isOwnFeed: widget.isMyFeed);
            },
          ),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String message;
  const _OfflineBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  final ActivityRecord activity;
  final bool isOwnFeed;
  const _ActivityFeedCard({required this.activity, this.isOwnFeed = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final duration = Duration(seconds: activity.durationSeconds);
    final timeStr = "${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => ActivityDetailScreen(activity: activity, isOwnActivity: isOwnFeed)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: GestureDetector(
                onTap: (activity.userId != null && !isOwnFeed)
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: activity.userId!,
                              userName: activity.userName,
                              userPhotoUrl: activity.userPhotoUrl,
                            ),
                          ),
                        )
                    : null,
                child: activity.userPhotoUrl != null
                    ? CircleAvatar(
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        child: ClipOval(
                          child: SecureImage(
                            imageUrl: activity.userPhotoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          activity.userName?.isNotEmpty == true ? activity.userName![0].toUpperCase() : '?',
                          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
              ),
              title: GestureDetector(
                onTap: (activity.userId != null && !isOwnFeed)
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: activity.userId!,
                              userName: activity.userName,
                              userPhotoUrl: activity.userPhotoUrl,
                            ),
                          ),
                        )
                    : null,
                child: Text(activity.userName ?? activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              subtitle: Text(
                '${activity.userName != null ? activity.title + " • " : ""}${DateFormat('dd MMMM, HH:mm').format(activity.startedAt)}',
              ),
              trailing: Icon(_getIconForKind(activity.kind), color: theme.colorScheme.primary, size: 20),
            ),
            if (activity.thumbnailUrl != null)
              SecureImage(
                imageUrl: activity.thumbnailUrl,
                height: 180,
                width: double.infinity,
                fallbackIcon: _getIconForKind(activity.kind),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(distanceKm, 'km'),
                  _statItem(timeStr, 'время'),
                  if (activity.avgHeartRate != null)
                    _statItem(activity.avgHeartRate.toString(), 'чсс'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  IconData _getIconForKind(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.run: return Icons.directions_run;
      case ActivityKind.roadCycling: return Icons.directions_bike;
      case ActivityKind.walk: return Icons.directions_walk;
      case ActivityKind.hike: return Icons.terrain;
      default: return Icons.sports_score;
    }
  }
}
