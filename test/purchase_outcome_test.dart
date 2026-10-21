import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/singletons/purchase_service.dart';

/// When a Google Play purchase may be consumed.
///
/// The rule these exist to hold still: **nothing but a confirmed credit may consume a purchase.**
/// Consuming is irreversible — Play never redelivers a consumed purchase — so a purchase that is
/// kept can still be retried, or refunded by Google after three days, while one consumed in error
/// is money taken for credits that never arrive. That is not hypothetical: a 409 was once read as
/// "already credited", and every purchase belonging to a session the device had lost was spent.
void main() {
  group('a successful call', () {
    test('credits the caller, and only then may it be consumed', () {
      final outcome = outcomeFor(creditedToCaller: true, callerIsGuest: false);

      expect(outcome, PurchaseOutcomeKind.credited);
      expect(outcome.mayConsume, isTrue);
    });

    test('that disclaims the credit is still not a credit', () {
      // The server credits the caller by construction, so this should never arrive. If it ever
      // does, the purchase is kept rather than assumed away.
      final outcome = outcomeFor(creditedToCaller: false, callerIsGuest: false);

      expect(outcome, PurchaseOutcomeKind.refusedOtherAccount);
      expect(outcome.mayConsume, isFalse);
    });
  });

  group('a 403', () {
    test('tells a guest to create an account, and keeps the purchase', () {
      // Recoverable: converting keeps the same account id, so the purchase matches on the next
      // restore and the credits arrive.
      final outcome =
          outcomeFor(creditedToCaller: false, statusCode: 403, callerIsGuest: true);

      expect(outcome, PurchaseOutcomeKind.refusedNeedsAccount);
      expect(outcome.mayConsume, isFalse);
    });

    test('tells a signed-in user it belongs elsewhere, and keeps the purchase', () {
      final outcome =
          outcomeFor(creditedToCaller: false, statusCode: 403, callerIsGuest: false);

      expect(outcome, PurchaseOutcomeKind.refusedOtherAccount);
      expect(outcome.mayConsume, isFalse);
    });
  });

  group('anything unresolved is deferred, never consumed', () {
    // 409: a concurrent grant is in flight. This is the exact code that used to be read as
    // success. 503: the auth service could not confirm the account. 0: no response at all.
    for (final status in [409, 500, 503, 0, 404]) {
      test('status $status', () {
        final outcome = outcomeFor(
            creditedToCaller: false, statusCode: status, callerIsGuest: false);

        expect(outcome, PurchaseOutcomeKind.deferred);
        expect(outcome.mayConsume, isFalse);
      });
    }
  });

  test('exactly one outcome may ever consume', () {
    // Guards the invariant against a future kind being added without thinking about it.
    expect(
      PurchaseOutcomeKind.values.where((k) => k.mayConsume),
      [PurchaseOutcomeKind.credited],
    );
  });
}
