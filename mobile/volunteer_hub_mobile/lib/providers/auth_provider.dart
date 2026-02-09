import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  Map<String, dynamic>? _user;
  String? _error;
  String? _infoMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  String? get infoMessage => _infoMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final res = await _api.login(email, password);
      final data = res.data as Map<String, dynamic>;
      _token = data['token'] as String?;
      _user = data['user'] as Map<String, dynamic>?;
      if (_token != null) {
        _api.setAuthToken(_token!);
        _api.onUnauthorized = () {
          _token = null;
          _user = null;
          _isAuthenticated = false;
          _api.clearAuthToken();
          notifyListeners();
        };
        _isAuthenticated = true;
      } else {
        _error = 'Neuspješna prijava';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        _error = 'Pogrešan email ili lozinka';
      } else {
        _error = 'Greška pri povezivanju sa serverom';
      }
      _isAuthenticated = false;
    } catch (e) {
      _error = 'Neočekivana greška: $e';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _isAuthenticated;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _isAuthenticated = false;
    _api.clearAuthToken();
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearInfoMessage() {
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final res = await _api.forgotPassword(email.trim());
      final data = res.data;
      if (data is Map && data['message'] is String) {
        _infoMessage = data['message'] as String;
      } else {
        _infoMessage = 'Ako korisnik sa unesenim emailom postoji, poslali smo upute za reset lozinke.';
      }
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && (e.response?.data['message'] is String)) {
        _error = e.response?.data['message'] as String;
      } else {
        _error = 'Greška pri slanju zahtjeva za reset lozinke.';
      }
      return false;
    } catch (_) {
      _error = 'Neočekivana greška pri resetu lozinke.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final res = await _api.resetPassword(
        email: email.trim(),
        token: token.trim(),
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      final data = res.data;
      if (data is Map && data['message'] is String) {
        _infoMessage = data['message'] as String;
      } else {
        _infoMessage = 'Lozinka je uspješno resetovana.';
      }
      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map && (e.response?.data['message'] is String)) {
        _error = e.response?.data['message'] as String;
      } else {
        _error = 'Reset lozinke nije uspio.';
      }
      return false;
    } catch (_) {
      _error = 'Neočekivana greška pri resetu lozinke.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}
