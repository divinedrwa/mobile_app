import 'package:divine_app/core/utils/amount_in_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amountInWordsIndian formats common amounts', () {
    expect(amountInWordsIndian(0), 'Zero Rupees Only');
    expect(amountInWordsIndian(1), 'One Rupee Only');
    expect(amountInWordsIndian(2500), 'Two Thousand Five Hundred Rupees Only');
    expect(amountInWordsIndian(125000), 'One Lakh Twenty Five Thousand Rupees Only');
  });

  test('financialYearLabel follows Apr–Mar FY', () {
    expect(financialYearLabel(6, 2025), 'FY 2025–26');
    expect(financialYearLabel(3, 2026), 'FY 2025–26');
    expect(financialYearLabel(4, 2026), 'FY 2026–27');
  });
}
