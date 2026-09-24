import 'package:flutter_test/flutter_test.dart';

import 'package:altkamel_app/core/constants/api_constants.dart';

void main() {
  test('the default API host is Laravel staging, never SAS', () {
    expect(ApiConstants.baseUrl, contains('api-staging.altkamel.ly/api/v1'));
    expect(ApiConstants.baseUrl, isNot(contains('admin.altkamel.ly')));
  });
}
