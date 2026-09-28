import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/payment.dart';

/// Result of starting a payment. For Esewa/Khalti, [redirectUrl] is where the
/// user should be sent to complete checkout; [formFields] carries the extra
/// POST fields eSewa expects (Khalti/COD don't need them).
class PaymentInitiationResult {
  final int paymentId;
  final String method;
  final String? redirectUrl;
  final Map<String, String>? formFields;
  final String message;

  PaymentInitiationResult({
    required this.paymentId,
    required this.method,
    this.redirectUrl,
    this.formFields,
    this.message = '',
  });
}

class PaymentProvider extends ChangeNotifier {
  List<Payment> _payments = [];
  final Map<int, Payment?> _byAppointment = {};
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  List<Payment> get payments => _payments;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  Payment? paymentForAppointment(int appointmentId) =>
      _byAppointment[appointmentId];

  /// Patient: every payment they've made.
  Future<void> fetchMine() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json =
          await ApiClient.instance.get(ApiConstants.paymentsMine) as List;
      _payments = json
          .cast<Map<String, dynamic>>()
          .map(Payment.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetches the payment(s) tied to one appointment (patient/doctor/admin,
  /// enforced server-side). Keeps the most recent as the cached result.
  Future<void> fetchForAppointment(int appointmentId) async {
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.paymentByAppointment(appointmentId));
      Payment? latest;
      if (json is List && json.isNotEmpty) {
        final list =
            json.cast<Map<String, dynamic>>().map(Payment.fromJson).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        latest = list.first;
      } else if (json is Map<String, dynamic>) {
        latest = Payment.fromJson(json);
      }
      _byAppointment[appointmentId] = latest;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<PaymentInitiationResult?> initiate({
    required int appointmentId,
    required String method,
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance.post(ApiConstants.paymentInitiate,
          body: {'appointmentId': appointmentId, 'method': method});
      final map = json as Map<String, dynamic>;
      PaymentInitiationResult result;
      if (method == PaymentMethod.esewa) {
        result = PaymentInitiationResult(
          paymentId: map['paymentId'] as int,
          method: method,
          redirectUrl: map['gatewayUrl'] as String?,
          formFields: (map['formFields'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      } else if (method == PaymentMethod.khalti) {
        result = PaymentInitiationResult(
          paymentId: map['paymentId'] as int,
          method: method,
          redirectUrl: map['paymentUrl'] as String?,
        );
      } else {
        result = PaymentInitiationResult(
          paymentId: map['paymentId'] as int,
          method: method,
          message: map['message'] as String? ??
              'Cash on delivery selected. Please pay at the hospital counter.',
        );
      }
      await fetchForAppointment(appointmentId);
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  /// Doctor/Admin: confirms cash was collected at the counter.
  Future<bool> collectCod(int paymentId, {int? appointmentId}) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.put(ApiConstants.paymentCollectCod(paymentId));
      if (appointmentId != null) await fetchForAppointment(appointmentId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }
}
