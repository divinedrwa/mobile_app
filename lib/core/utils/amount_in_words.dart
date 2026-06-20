/// Converts a rupee amount to words (Indian numbering: lakh, crore).
/// Paise are ignored — maintenance invoices use whole rupees.
String amountInWordsIndian(num amount) {
  final rupees = amount.round();
  if (rupees == 0) return 'Zero Rupees Only';
  if (rupees < 0) return 'Minus ${amountInWordsIndian(-rupees)}';

  final words = _intToWords(rupees);
  final unit = rupees == 1 ? 'Rupee' : 'Rupees';
  return '$words $unit Only';
}

String _intToWords(int n) {
  if (n == 0) return 'Zero';

  const ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  String under1000(int x) {
    if (x == 0) return '';
    if (x < 20) return ones[x];
    if (x < 100) {
      final t = tens[x ~/ 10];
      final r = x % 10;
      return r == 0 ? t : '$t ${ones[r]}';
    }
    final h = x ~/ 100;
    final r = x % 100;
    final head = '${ones[h]} Hundred';
    if (r == 0) return head;
    return '$head ${_intToWords(r)}';
  }

  final parts = <String>[];
  var remaining = n;

  final crore = remaining ~/ 10000000;
  if (crore > 0) {
    parts.add('${_intToWords(crore)} Crore');
    remaining %= 10000000;
  }

  final lakh = remaining ~/ 100000;
  if (lakh > 0) {
    parts.add('${_intToWords(lakh)} Lakh');
    remaining %= 100000;
  }

  final thousand = remaining ~/ 1000;
  if (thousand > 0) {
    parts.add('${_intToWords(thousand)} Thousand');
    remaining %= 1000;
  }

  if (remaining > 0) {
    parts.add(under1000(remaining));
  }

  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Indian financial year label from calendar month/year (Apr–Mar).
String financialYearLabel(int month, int year) {
  if (month < 1 || month > 12) return '';
  final fyStart = month >= 4 ? year : year - 1;
  final fyEnd = (fyStart + 1) % 100;
  return 'FY $fyStart–${fyEnd.toString().padLeft(2, '0')}';
}
