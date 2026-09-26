import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/notification_api.dart';
import '../../../../data/services/realtime_client.dart';
import '../../../../domain/models/notification_item.dart';

class NotificationCenterViewModel extends ChangeNotifier {
  NotificationCenterViewModel({
    required NotificationApi api,
    required RealtimeClient realtime,
    required String userId,
  }) : _api = api,
       _realtime = realtime,
       _userId = userId {
    _subscription = _realtime.messages.listen(_onRealtime);
    if (_userId.isNotEmpty) {
      unawaited(_realtime.connect());
      unawaited(_realtime.subscribe('user:$_userId'));
    } else {
      loading = false;
    }
    unawaited(refresh());
  }

  final NotificationApi _api;
  final RealtimeClient _realtime;
  final String _userId;
  StreamSubscription<RealtimeMessage>? _subscription;

  List<NotificationItem> items = const [];
  int unreadCount = 0;
  bool loading = true;
  bool busy = false;
  String? errorMessage;

  Future<void> refresh() async {
    if (_userId.isEmpty) return;
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _api.list();
      items = page.items;
      unreadCount = page.unreadCount;
    } catch (_) {
      errorMessage = 'Could not load notifications.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.read || item.id.isEmpty) return;
    _replace(item.copyWith(read: true));
    unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
    notifyListeners();
    try {
      await _api.markRead(item.id);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0 || busy) return;
    busy = true;
    notifyListeners();
    try {
      await _api.markAllRead();
      items = [for (final item in items) item.copyWith(read: true)];
      unreadCount = 0;
    } catch (_) {
      errorMessage = 'Could not mark notifications as read.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _onRealtime(RealtimeMessage message) {
    if (message.event != 'notification') return;
    final item = NotificationItem.fromJson(message.data);
    if (item.id.isEmpty || items.any((existing) => existing.id == item.id)) {
      return;
    }
    items = [item, ...items];
    unreadCount += 1;
    notifyListeners();
  }

  void _replace(NotificationItem item) {
    items = [
      for (final current in items) current.id == item.id ? item : current,
    ];
  }

  @override
  void dispose() {
    if (_userId.isNotEmpty) {
      unawaited(_realtime.unsubscribe('user:$_userId'));
    }
    _subscription?.cancel();
    super.dispose();
  }
}
