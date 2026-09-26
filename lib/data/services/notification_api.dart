import '../../domain/models/notification_item.dart';
import 'api_client.dart';

class NotificationPage {
  const NotificationPage({required this.items, required this.unreadCount});

  final List<NotificationItem> items;
  final int unreadCount;
}

class NotificationApi {
  NotificationApi(this._api);

  final ApiClient _api;

  Future<NotificationPage> list({int limit = 50}) async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    final data = response.data ?? const {};
    final raw = data['notifications'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <NotificationItem>[];
    return NotificationPage(
      items: items,
      unreadCount:
          (data['unreadCount'] as num?)?.toInt() ??
          items.where((item) => !item.read).length,
    );
  }

  Future<void> markRead(String id) async {
    await _api.dio.patch<Map<String, dynamic>>('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.dio.post<Map<String, dynamic>>('/notifications/read-all');
  }
}
