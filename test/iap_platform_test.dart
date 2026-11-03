import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountainrider/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'mountainriderstar'});
    expect(StoreService.starId, 'mountainriderstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'mountainridercoffee', 'mountainriderchocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('mountainriderstar')));
  });
}
