import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/data/config/api_errors.dart';

void main() {
  test('phone taken copy names the existing role', () {
    expect(
      phoneTakenMessage('passenger'),
      'This number already has a passenger account. Sign in instead.',
    );
    expect(
      phoneTakenMessage('driver'),
      'This number already has a driver account. Sign in instead.',
    );
  });

  test('error payload reads nested nest conflict bodies', () {
    final payload = errorPayload({
      'statusCode': 409,
      'error': 'Conflict',
      'message': {'error': 'phone_taken', 'role': 'passenger'},
    });
    expect(payload?['error'], 'phone_taken');
    expect(payload?['role'], 'passenger');
  });

  test('error payload reads a flat identity body', () {
    final payload = errorPayload({
      'error': 'phone_taken',
      'role': 'driver',
    });
    expect(payload?['error'], 'phone_taken');
    expect(payload?['role'], 'driver');
  });
}
