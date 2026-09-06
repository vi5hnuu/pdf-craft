import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/singletons/CreditService.dart';

/// The client quotes a price before spending credits, so its arithmetic has to match the
/// server's exactly — a quote that is lower than the charge is how users lose trust in a
/// credit system.
void main() {
  group('ToolCost.costFor', () {
    test('a flat-priced tool costs the same regardless of size', () {
      const cost = ToolCost(
        toolId: 'grayscale-pdf', baseCredits: 1,
        sizeUnit: 'NONE', creditsPerUnit: 0, unitSize: 1,
      );

      expect(cost.costFor(0), 1);
      expect(cost.costFor(50 * 1024 * 1024), 1);
      expect(cost.hasSizeComponent, isFalse);
    });

    test('a size-priced tool adds one credit per completed block', () {
      // Mirrors the seeded compress-pdf row: base 2, +1 per 5 MB.
      const cost = ToolCost(
        toolId: 'compress-pdf', baseCredits: 2,
        sizeUnit: 'BYTES', creditsPerUnit: 1, unitSize: 5000000,
      );

      expect(cost.costFor(0), 2, reason: 'no size means base only');
      expect(cost.costFor(4999999), 2, reason: 'a partial block does not add a credit');
      expect(cost.costFor(5000000), 3, reason: 'the first full block adds one');
      expect(cost.costFor(12000000), 4, reason: 'two full blocks add two');
      expect(cost.hasSizeComponent, isTrue);
    });

    test('a negative or zero size never costs less than the base', () {
      const cost = ToolCost(
        toolId: 'compress-pdf', baseCredits: 2,
        sizeUnit: 'BYTES', creditsPerUnit: 1, unitSize: 5000000,
      );

      expect(cost.costFor(-1), 2);
      expect(cost.costFor(0), 2);
    });

    test('a malformed row degrades to the base rather than overcharging', () {
      // unitSize of 0 would divide by zero; creditsPerUnit of 0 means no surcharge.
      const zeroUnit = ToolCost(
        toolId: 'x', baseCredits: 3, sizeUnit: 'BYTES', creditsPerUnit: 1, unitSize: 0,
      );
      const noPerUnit = ToolCost(
        toolId: 'x', baseCredits: 3, sizeUnit: 'BYTES', creditsPerUnit: 0, unitSize: 100,
      );

      expect(zeroUnit.costFor(10000), 3);
      expect(noPerUnit.costFor(10000), 3);
    });

    test('parses the server row, defaulting anything missing', () {
      final parsed = ToolCost.fromJson({
        'toolId': 'compress-pdf',
        'baseCredits': 2,
        'sizeUnit': 'BYTES',
        'creditsPerUnit': 1,
        'unitSize': 5000000,
      });

      expect(parsed.toolId, 'compress-pdf');
      expect(parsed.costFor(5000000), 3);

      final sparse = ToolCost.fromJson({'toolId': 'merge-pdf'});
      expect(sparse.baseCredits, 0, reason: 'an unpriced tool is free, not broken');
      expect(sparse.costFor(999999), 0);
    });
  });
}
