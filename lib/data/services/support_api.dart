import 'api_client.dart';

class SupportTicketCreated {
  const SupportTicketCreated({required this.ticketId});

  final String ticketId;
}

class SupportApi {
  SupportApi(this._api);

  final ApiClient _api;

  Future<SupportTicketCreated> createTicket({
    required String subject,
    String? body,
    String? rideId,
    String category = 'ride',
    String? userName,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/support/tickets',
      data: {
        'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
        if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
        'category': category,
        if (userName != null && userName.isNotEmpty) 'userName': userName,
      },
    );
    final data = response.data ?? const {};
    final ticket = data['ticket'];
    final id = ticket is Map ? '${ticket['id'] ?? ''}' : '';
    return SupportTicketCreated(ticketId: id);
  }
}
