import 'package:altkamel_app/features/portal/data/portal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a Laravel card recharge and only accepts its checkout URL', () {
    final recharge = CardRecharge.fromJson({
      'id': 'payment-id',
      'state': 'checkout_ready',
      'amount_minor': 1000,
      'currency': 'LYD',
      'checkout_url': 'https://pay.altkamel.ly/checkout/payment-id',
    });

    expect(recharge.id, 'payment-id');
    expect(recharge.amountLyd, 1);
    expect(recharge.checkoutUrl?.scheme, 'https');
    expect(recharge.checkoutUrl?.host, 'pay.altkamel.ly');
    expect(recharge.isFinal, isFalse);
  });

  test('recognizes only terminal Laravel payment states as final', () {
    final credited = CardRecharge.fromJson({
      'id': 'payment-id',
      'state': 'credited',
      'amount_minor': 1000,
      'currency': 'LYD',
    });

    expect(credited.isFinal, isTrue);
  });
}
