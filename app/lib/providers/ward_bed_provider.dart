import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/bed.dart';
import '../models/ward.dart';

class WardBedProvider extends ChangeNotifier {
  List<Ward> _wards = [];
  List<Bed> _availableBeds = [];
  bool _loading = false;
  String? _error;

  List<Ward> get wards => _wards;
  List<Bed> get availableBeds => _availableBeds;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchWards() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance.get(ApiConstants.wards) as List;
      _wards = json.cast<Map<String, dynamic>>().map(Ward.fromJson).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Beds currently free to admit a patient into, across all wards.
  Future<void> fetchAvailableBeds() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.bedsWithStatus('Available')) as List;
      _availableBeds =
          json.cast<Map<String, dynamic>>().map(Bed.fromJson).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
