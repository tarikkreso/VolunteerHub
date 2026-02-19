import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final res = await _api.login(email, password);
      final data = res.data;
      _api.setToken(data['token']);
      _user = data['user'] is Map<String, dynamic>
          ? data['user']
          : (data['user'] as Map).cast<String, dynamic>();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        _error = e.response?.data['message']?.toString() ?? 'Pogrešan email ili lozinka';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        _error = 'Nije moguće povezati se sa serverom';
      } else {
        _error = 'Greška pri prijavi';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Neočekivana greška: $e';
      notifyListeners();
      return false;
    }
  }

  void updateUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  void logout() {
    _user = null;
    _isAuthenticated = false;
    _api.setToken(null);
    notifyListeners();
  }
}

