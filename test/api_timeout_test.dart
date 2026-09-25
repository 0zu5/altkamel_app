import 'package:altkamel_app/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network and startup storage have finite timeout limits', () {
    expect(ApiConstants.requestTimeout, const Duration(seconds: 15));
    expect(ApiConstants.secureStorageTimeout, const Duration(seconds: 5));
  });
}
