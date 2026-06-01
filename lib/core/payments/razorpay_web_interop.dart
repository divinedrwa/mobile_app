import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Callback signatures mirroring Razorpay Checkout.js events.
typedef RazorpaySuccessCallback = void Function(RazorpayWebSuccess response);
typedef RazorpayErrorCallback = void Function(RazorpayWebError response);

/// Success payload from Checkout.js.
class RazorpayWebSuccess {
  RazorpayWebSuccess({
    this.paymentId,
    this.orderId,
    this.signature,
  });

  final String? paymentId;
  final String? orderId;
  final String? signature;
}

/// Error payload from Checkout.js.
class RazorpayWebError {
  RazorpayWebError({this.code, this.description, this.source, this.reason});

  final int? code;
  final String? description;
  final String? source;
  final String? reason;

  String get message =>
      description?.isNotEmpty == true ? description! : 'Payment failed';
}

// ---------------------------------------------------------------------------
// JS interop types for the global `Razorpay` constructor exposed by
// https://checkout.razorpay.com/v1/checkout.js
// ---------------------------------------------------------------------------

@JS('Razorpay')
extension type _RazorpayJS._(JSObject _) implements JSObject {
  external factory _RazorpayJS(JSObject options);
  external void open();
  external void close();
}

/// Opens the Razorpay Checkout.js popup and returns when the user completes
/// or cancels the payment.
///
/// [options] must include the standard Razorpay keys (`key`, `amount`,
/// `order_id`, etc.). Callbacks (`handler`, `modal.ondismiss`) are wired
/// internally.
void openRazorpayCheckout({
  required Map<String, dynamic> options,
  required RazorpaySuccessCallback onSuccess,
  required RazorpayErrorCallback onError,
}) {
  final jsOptions = _mapToJSObject(options);

  // Wire the success handler.
  jsOptions['handler'] = ((JSObject response) {
    onSuccess(RazorpayWebSuccess(
      paymentId: _jsString(response, 'razorpay_payment_id'),
      orderId: _jsString(response, 'razorpay_order_id'),
      signature: _jsString(response, 'razorpay_signature'),
    ));
  }).toJS;

  // Wire modal dismiss as an error (user closed popup).
  final modalObj = JSObject();
  modalObj['ondismiss'] = (() {
    onError(RazorpayWebError(
      code: 2,
      description: 'Payment cancelled by user',
      source: 'modal',
      reason: 'dismiss',
    ));
  }).toJS;
  jsOptions['modal'] = modalObj;

  final rzp = _RazorpayJS(jsOptions);
  rzp.open();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads a string property from a JS object, returning null if absent.
String? _jsString(JSObject obj, String key) {
  final val = obj[key];
  if (val == null || val.isUndefinedOrNull) return null;
  return (val as JSString).toDart;
}

/// Recursively converts a Dart Map to a plain JS object.
JSObject _mapToJSObject(Map<String, dynamic> map) {
  final obj = JSObject();
  for (final entry in map.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) {
      continue;
    } else if (value is String) {
      obj[key] = value.toJS;
    } else if (value is int) {
      obj[key] = value.toJS;
    } else if (value is double) {
      obj[key] = value.toJS;
    } else if (value is bool) {
      obj[key] = value.toJS;
    } else if (value is Map<String, dynamic>) {
      obj[key] = _mapToJSObject(value);
    } else {
      // Fallback: convert to string.
      obj[key] = value.toString().toJS;
    }
  }
  return obj;
}
