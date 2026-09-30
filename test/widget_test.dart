import 'package:flutter_test/flutter_test.dart';
import 'package:fuckxter_app/models/account.dart';

void main() {
  test('parses account profile data', () {
    final account = Account.fromJson({
      'profile': {
        'name': 'FuckXter',
        'handle': 'fuckxter',
        'email': 'test@example.com',
        'bio': 'test',
      },
    });

    expect(account.name, 'FuckXter');
    expect(account.handle, 'fuckxter');
  });
}
