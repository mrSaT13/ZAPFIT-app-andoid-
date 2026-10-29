import 'package:flutter/material.dart';

import 'package:endurain/core/models/activity_models.dart';
import 'package:endurain/core/services/activity_comments_service.dart';
import 'package:endurain/core/services/user_service.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/shared/widgets/secure_image.dart';

/// Server-side comments for one activity, shown on the detail screen.
///
/// Hidden entirely for local (not yet uploaded) activities — comments live on
/// the server the same way likes do. Offline just shows the cached failure of
/// the initial load as an empty state; retries are cheap (pull-to-refresh on
/// the parent refreshes this section too).
class ActivityCommentsSection extends StatefulWidget {
  const ActivityCommentsSection({super.key, required this.activity, required this.isOwnActivity});

  final ActivityRecord activity;
  final bool isOwnActivity;

  @override
  State<ActivityCommentsSection> createState() => _ActivityCommentsSectionState();
}

class _ActivityCommentsSectionState extends State<ActivityCommentsSection> {
  final ActivityCommentsService _service = ActivityCommentsService.instance;
  final UserService _userService = serviceLocator<UserService>();
  final TextEditingController _draftController = TextEditingController();
  final ScrollController _listScroll = ScrollController();
  final FocusNode _draftFocus = FocusNode();

  bool _loading = true;
  List<ActivityCommentRecord> _comments = [];
  int? _targetActivityId;

  bool get _hasServerActivity => _targetActivityId != null;

  @override
  void initState() {
    super.initState();
    _syncTarget();
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant ActivityCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_targetActivityId != (widget.activity.serverId)) {
      _syncTarget();
      _loadComments();
    }
  }

  @override
  void dispose() {
    _draftController.dispose();
    _listScroll.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  void _syncTarget() {
    _targetActivityId = widget.activity.serverId;
  }

  Future<void> _loadComments() async {
    final serverId = _targetActivityId;
    if (serverId == null) return;
    setState(() => _loading = true);
    final list = await _service.fetchComments(serverId);
    if (!mounted || _targetActivityId != serverId) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  Future<void> _sendDraft() async {
    final serverId = _targetActivityId;
    final text = _draftController.text.trim();
    if (serverId == null || text.isEmpty) return;
    _draftController.clear();
    _draftFocus.unfocus();
    final created = await _service.createComment(serverId, text);
    if (!mounted || _targetActivityId != serverId) return;
    if (created == null) {
      // Restore the draft so nothing typed is lost on a network hiccup.
      _draftController.text = text;
      _draftFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить комментарий — текст сохранён')),
        );
      return;
    }
    setState(() => _comments = [..._comments, created]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_listScroll.hasClients) {
      await _listScroll.animateTo(
        _listScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isMine(ActivityCommentRecord c) => c.userId == _userService.profile?.id;

  Future<void> _editComment(ActivityCommentRecord comment) async {
    final ctrl = TextEditingController(text: comment.content);
    final newText = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить комментарий'),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == comment.content) return;
    final updated = await _service.updateComment(comment.id, newText);
    if (updated != null && mounted) {
      setState(() {
        _comments = _comments
            .map((c) => c.id == comment.id ? updated : c)
            .toList(growable: false);
      });
    }
  }

  Future<void> _deleteComment(ActivityCommentRecord comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _service.deleteComment(comment.id);
    if (deleted && mounted) {
      setState(() => _comments = _comments.where((c) => c.id != comment.id).toList(growable: false));
    }
  }

  void _longPressComment(ActivityCommentRecord comment) {
    if (!_isMine(comment)) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Изменить'),
              onTap: () {
                Navigator.pop(ctx);
                _editComment(comment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteComment(comment);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_hasServerActivity) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Комментарии', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${_comments.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Пока тихо — напиши первым',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  controller: _listScroll,
                  shrinkWrap: true,
                  itemCount: _comments.length,
                  itemBuilder: (ctx, i) => _buildCommentTile(_comments[i], theme),
                ),
              ),
            const SizedBox(height: 8),
            _buildDraftField(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(ActivityCommentRecord comment, ThemeData theme) {
    return FutureBuilder<String?>(
      future: _service.resolveAuthorName(comment.userId),
      builder: (ctx, snap) {
        final name = snap.data ?? 'Спортсмен';
        final isEdited = comment.updatedAt != null;
        final subtitle = _isMine(comment) && isEdited ? 'изменено' : _timeAgo(comment.createdAt);
        return InkWell(
          onLongPress: () => _longPressComment(comment),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: _service.resolveAuthorPhoto(comment.userId),
                  builder: (ctx, photoSnap) {
                    final photo = photoSnap.data;
                    if (photo != null && photo.isNotEmpty) {
                      return SecureImage(imageUrl: photo, width: 36, height: 36);
                    }
                    return CircleAvatar(
                      radius: 18,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SelectableText(comment.content, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (_isMine(comment))
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _editComment(comment);
                      } else if (v == 'delete') {
                        _deleteComment(comment);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Изменить')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now().toUtc();
    final dtUtc = dt.isUtc ? dt : dt.toUtc();
    final diff = now.difference(dtUtc);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return '${diff.inHours} ч';
    if (diff.inDays < 7) return '${diff.inDays} дн';
    return '${dtUtc.day.toString().padLeft(2, '0')}.${dtUtc.month.toString().padLeft(2, '0')}';
  }

  Widget _buildDraftField(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _draftController,
            focusNode: _draftFocus,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendDraft(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              hintText: 'Написать комментарий…',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _draftController,
          builder: (ctx, value, _) {
            final enabled = value.text.trim().isNotEmpty;
            return IconButton.filled(
              onPressed: enabled ? _sendDraft : null,
              icon: const Icon(Icons.send, size: 18),
            );
          },
        ),
      ],
    );
  }
}
