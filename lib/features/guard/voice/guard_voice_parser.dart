import '../data/guard_visitor_type.dart';

/// What a guard said for a new visitor, split into form fields.
///
/// Example: "Ramesh Kumar nine eight seven six five four three two one zero
/// flat A twenty five delivery" → name, phone, flat and category.
class ParsedVisitorEntry {
  const ParsedVisitorEntry({
    this.name,
    this.phone,
    this.flatLabels = const [],
    this.visitorType,
    this.vehicleNumber,
  });

  final String? name;
  final String? phone;

  /// Flat labels exactly as passed in `knownFlatLabels` (e.g. "A-25").
  final List<String> flatLabels;
  final GuardCheckInVisitorType? visitorType;
  final String? vehicleNumber;

  bool get isEmpty =>
      name == null &&
      phone == null &&
      flatLabels.isEmpty &&
      visitorType == null &&
      vehicleNumber == null;
}

const _units = {
  'zero': 0, 'oh': 0, 'o': 0, 'one': 1, 'two': 2, 'to': 2, 'too': 2,
  'three': 3, 'four': 4, 'for': 4, 'five': 5, 'six': 6, 'seven': 7,
  'eight': 8, 'nine': 9,
};
const _teens = {
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
  'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
  'nineteen': 19,
};
const _tens = {
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
  'seventy': 70, 'eighty': 80, 'ninety': 90,
};

const _typeKeywords = <GuardCheckInVisitorType, List<String>>{
  GuardCheckInVisitorType.delivery: [
    'delivery', 'courier', 'parcel', 'package', 'zomato', 'swiggy', 'amazon',
    'flipkart', 'blinkit', 'zepto', 'bigbasket', 'dunzo', 'food',
  ],
  GuardCheckInVisitorType.cab: ['cab', 'taxi', 'uber', 'ola', 'rapido', 'auto'],
  GuardCheckInVisitorType.serviceProvider: [
    'service', 'plumber', 'electrician', 'carpenter', 'technician', 'repair',
    'mechanic', 'maid', 'cook', 'cleaner', 'painter', 'ac',
  ],
  GuardCheckInVisitorType.vendor: ['vendor', 'supplier', 'seller', 'salesman'],
  GuardCheckInVisitorType.guest: [
    'guest', 'friend', 'relative', 'family', 'visitor', 'mehman',
  ],
};

/// Words that are never part of a visitor's name.
const _nonNameWords = {
  'flat', 'villa', 'house', 'block', 'number', 'no', 'mobile', 'phone',
  'name', 'is', 'my', 'the', 'and', 'to', 'for', 'from', 'going', 'visiting',
  'came', 'come', 'coming', 'at', 'in', 'of', 'with', 'his', 'her', 'vehicle',
  'car', 'bike', 'scooter', 'plate', 'hai', 'ka', 'ki', 'ke', 'se', 'mein',
  'ko', 'naam', 'sir', 'madam', 'mr', 'mrs', 'ms', 'double', 'triple',
  'please', 'entry', 'gate', 'here', 'this', 'a', 'an',
};

/// Converts spoken number words to digit tokens ("twenty five" → "25",
/// "double seven" → "77"); other tokens pass through unchanged.
List<String> _normalizeNumbers(List<String> words) {
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if ((w == 'double' || w == 'triple') && i + 1 < words.length) {
      final next = words[i + 1];
      final d = _units[next] ?? (RegExp(r'^\d$').hasMatch(next) ? int.parse(next) : null);
      if (d != null) {
        out.add(List.filled(w == 'double' ? 2 : 3, '$d').join());
        i++;
        continue;
      }
    }
    if (_tens.containsKey(w)) {
      final next = i + 1 < words.length ? words[i + 1] : null;
      final unit = next == null ? null : _units[next];
      if (unit != null && unit != 0 && next != 'to' && next != 'for') {
        out.add('${_tens[w]! + unit}');
        i++;
      } else {
        out.add('${_tens[w]}');
      }
      continue;
    }
    if (_teens.containsKey(w)) {
      out.add('${_teens[w]}');
      continue;
    }
    // "to"/"for"/"o" are digits only between other digits ("nine for three").
    if (_units.containsKey(w)) {
      final ambiguous = w == 'to' || w == 'too' || w == 'for' || w == 'o';
      final prevDigit = out.isNotEmpty && RegExp(r'^\d+$').hasMatch(out.last);
      final next = i + 1 < words.length ? words[i + 1] : '';
      final nextDigit = RegExp(r'^\d+$').hasMatch(next) ||
          (_units.containsKey(next) && !const {'to', 'too', 'for', 'o'}.contains(next)) ||
          _teens.containsKey(next) ||
          _tens.containsKey(next) ||
          next == 'double' ||
          next == 'triple';
      if (!ambiguous || (prevDigit && nextDigit)) {
        out.add('${_units[w]}');
        continue;
      }
    }
    out.add(w);
  }
  return out;
}

String _normalizeFlat(String label) =>
    label.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Flat key without leading zeros in the number part ("A-05" → "A5").
String _flatKey(String? block, String number) {
  final n = int.tryParse(number)?.toString() ?? number.toUpperCase();
  return '${(block ?? '').toUpperCase()}$n';
}

/// Parses one spoken sentence into visitor fields. [knownFlatLabels] are the
/// flats shown in the picker (e.g. "A-25"); only those can be matched.
ParsedVisitorEntry parseVisitorUtterance(
  String transcript, {
  List<String> knownFlatLabels = const [],
}) {
  final raw = transcript.toLowerCase().replaceAll(RegExp(r"[,.;:!?']"), ' ');
  final words = raw
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      // Split glued forms like "a25" / "a-25" into block + number.
      .expand((w) {
        final m = RegExp(r'^([a-z])-?(\d{1,4})$').firstMatch(w);
        return m == null ? [w.replaceAll('-', '')] : [m.group(1)!, m.group(2)!];
      })
      .toList();
  final tokens = _normalizeNumbers(words);
  final isDigits = RegExp(r'^\d+$');

  // Known flats by key: "A25" → "A-25"; also number-only keys when unambiguous.
  final flatByKey = <String, String>{};
  final numberOnly = <String, List<String>>{};
  for (final label in knownFlatLabels) {
    final m = RegExp(r'^([A-Za-z]+)?[-\s]?0*(\d+)$').firstMatch(label.trim());
    if (m != null) {
      flatByKey[_flatKey(m.group(1), m.group(2)!)] = label;
      numberOnly.putIfAbsent(int.parse(m.group(2)!).toString(), () => []).add(label);
    } else {
      flatByKey[_normalizeFlat(label)] = label;
    }
  }

  final used = List<bool>.filled(tokens.length, false);

  // Phone: a run of digit tokens adding up to 10+ digits.
  String? phone;
  for (var i = 0; i < tokens.length && phone == null; i++) {
    if (!isDigits.hasMatch(tokens[i])) continue;
    var j = i;
    final buf = StringBuffer();
    while (j < tokens.length && isDigits.hasMatch(tokens[j])) {
      buf.write(tokens[j]);
      j++;
    }
    var digits = buf.toString();
    if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length >= 10) {
      phone = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      for (var k = i; k < j; k++) {
        used[k] = true;
      }
    }
  }

  // Flats: "<block> <number>" or "flat/villa/house <number>".
  final flats = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    if (used[i] || !isDigits.hasMatch(tokens[i]) || tokens[i].length > 4) continue;
    final prev = i > 0 ? tokens[i - 1] : '';
    String? label;
    if (RegExp(r'^[a-z]$').hasMatch(prev)) {
      label = flatByKey[_flatKey(prev, tokens[i])];
      if (label != null) used[i - 1] = true;
    }
    if (label == null) {
      final candidates = numberOnly[int.parse(tokens[i]).toString()] ?? const [];
      final keyword = const {'flat', 'villa', 'house', 'number', 'no'}.contains(prev);
      if (candidates.length == 1 && (keyword || tokens[i].length >= 2)) {
        label = candidates.first;
      }
    }
    if (label != null && !flats.contains(label)) {
      flats.add(label);
      used[i] = true;
    }
  }

  // Vehicle number, e.g. "M H 12 A B 1234" → "MH12AB1234" (phone/flat tokens excluded).
  final vehicle = _plateFrom([
    for (var i = 0; i < tokens.length; i++)
      if (!used[i]) tokens[i],
  ]);

  // Category from keywords.
  GuardCheckInVisitorType? type;
  for (final entry in _typeKeywords.entries) {
    if (tokens.any(entry.value.contains)) {
      type = entry.key;
      break;
    }
  }
  final keywordSet = _typeKeywords.values.expand((e) => e).toSet();

  // Name: after "name is"/"naam", else the leading words that aren't numbers or keywords.
  String? name;
  final nameWords = <String>[];
  var start = 0;
  for (var i = 0; i + 1 < tokens.length; i++) {
    if ((tokens[i] == 'name' && tokens[i + 1] == 'is') ) {
      start = i + 2;
      break;
    }
    if (tokens[i] == 'naam') {
      start = i + 1;
      break;
    }
  }
  for (var i = start; i < tokens.length && nameWords.length < 3; i++) {
    final t = tokens[i];
    final wordLike = RegExp(r'^[a-z]{2,}$').hasMatch(t);
    if (used[i] || !wordLike || _nonNameWords.contains(t) || keywordSet.contains(t)) {
      if (nameWords.isNotEmpty) break;
      continue;
    }
    nameWords.add(t);
  }
  if (nameWords.isNotEmpty) {
    name = nameWords.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  return ParsedVisitorEntry(
    name: name,
    phone: phone,
    flatLabels: flats,
    visitorType: type,
    vehicleNumber: vehicle,
  );
}

/// Digits from a spoken phone number ("nine eight double seven …").
String digitsFromSpeech(String transcript) {
  final words = transcript
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return _normalizeNumbers(words)
      .where((t) => RegExp(r'^\d+$').hasMatch(t))
      .join();
}

/// Vehicle number from speech or OCR text ("MH 12 AB 1234" → "MH12AB1234").
String? vehicleFromText(String text) {
  final words = text.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  return _plateFrom(_normalizeNumbers(words));
}

/// Joins plate-like tokens (digits, 1–3 letter groups like "MH"/"AB") and finds
/// an Indian registration number; ordinary words ("guest", "vehicle") are skipped.
String? _plateFrom(List<String> tokens) {
  const skip = {'to', 'is', 'an', 'of', 'in', 'at', 'my', 'no', 'and', 'the', 'for', 'car', 'hai'};
  final compact = tokens
      .where((t) =>
          RegExp(r'^\d+$').hasMatch(t) ||
          (RegExp(r'^[a-z]{1,3}$').hasMatch(t) && !skip.contains(t)) ||
          RegExp(r'^[a-z]{2}\d').hasMatch(t))
      .join()
      .toUpperCase();
  return RegExp(r'([A-Z]{2}\d{1,2}[A-Z]{0,3}\d{4}|\d{2}BH\d{4}[A-Z]{1,2})')
      .firstMatch(compact)
      ?.group(1);
}
