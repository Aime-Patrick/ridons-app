import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeMessage {
  const RealtimeMessage({required this.event, required this.data});

  final String event;
  final Map<String, dynamic> data;
}

/// Socket.IO client for notification `/ws` (proxied through the gateway).
class RealtimeClient {
  RealtimeClient({required this.wsUrl, required this.readToken});

  final String wsUrl;
  final Future<String?> Function() readToken;

  io.Socket? _socket;
  final _controller = StreamController<RealtimeMessage>.broadcast();
  final _channels = <String>{};

  Stream<RealtimeMessage> get messages => _controller.stream;
  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return;
    if (_socket?.connected == true) return;
    if (_socket != null) {
      _socket!.connect();
      return;
    }

    final socket = io.io(wsUrl, <String, dynamic>{
      'path': '/ws',
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'forceNew': true,
      'auth': {'token': token},
    });
    _socket = socket;

    socket.onConnect((_) {
      for (final channel in _channels) {
        socket.emit('subscribe', {'channel': channel});
      }
    });
    socket.onDisconnect((_) {});
    socket.onConnectError((_) {});
    socket.on('location', (data) => _emit('location', data));
    socket.on('eta', (data) => _emit('eta', data));
    socket.on('status', (data) => _emit('status', data));
    socket.on('presence', (data) => _emit('presence', data));
    socket.on('matched', (data) => _emit('matched', data));
    socket.on('timeout', (data) => _emit('timeout', data));
    socket.on('dispatch', (data) => _emit('dispatch', data));
    socket.on('incoming_request', (data) => _emit('incoming_request', data));
    socket.on('bid', (data) => _emit('bid', data));
    socket.on('passenger_counter', (data) => _emit('passenger_counter', data));
    socket.on('notification', (data) => _emit('notification', data));
    socket.connect();
  }

  Future<void> subscribe(String channel) async {
    if (channel.isEmpty) return;
    _channels.add(channel);
    _socket?.emit('subscribe', {'channel': channel});
  }

  Future<void> unsubscribe(String channel) async {
    _channels.remove(channel);
    _socket?.emit('unsubscribe', {'channel': channel});
  }

  Future<void> syncDriverChannels(Iterable<String> driverIds) async {
    final next = driverIds.map((id) => 'driver:$id').toSet();
    final drop = _channels
        .where((c) => c.startsWith('driver:') && !next.contains(c))
        .toList();
    for (final channel in drop) {
      await unsubscribe(channel);
    }
    for (final channel in next) {
      await subscribe(channel);
    }
  }

  void _emit(String event, dynamic data) {
    if (_controller.isClosed) return;
    Map<String, dynamic> map = {};
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }
    _controller.add(RealtimeMessage(event: event, data: map));
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}
