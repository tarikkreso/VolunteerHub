import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EventsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _events = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalCount = 0;
  int? _selectedCategoryId;
  
  List<dynamic> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _totalCount;
  
  Future<void> loadEvents({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _events = [];
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.getEvents(
        page: _currentPage,
        pageSize: 10,
        categoryId: _selectedCategoryId,
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _events = [..._events, ...data['items'] as List];
        _totalCount = data['totalCount'] as int;
        _currentPage++;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void setCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadEvents(refresh: true);
  }
  
  bool get hasMoreEvents => _events.length < _totalCount;
}
