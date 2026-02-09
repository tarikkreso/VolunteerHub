import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _authToken;
  String? get token => _authToken;
  String get baseUrl => ApiConfig.baseUrl;
  VoidCallback? onUnauthorized;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          clearAuthToken();
          onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;

  // ── Generic ──
  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);
  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);
  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);
  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);

  // ── Auth ──
  Future<Response> login(String email, String password) =>
      post(ApiConfig.login, data: {'email': email, 'password': password});
  Future<Response> register(Map<String, dynamic> data) =>
      post(ApiConfig.register, data: data);
  Future<Response> forgotPassword(String email) =>
      post(ApiConfig.forgotPassword, data: {'email': email});
  Future<Response> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) =>
      post(ApiConfig.resetPassword, data: {
        'email': email,
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });
  Future<Response> getMe() => get('/auth/me');
  Future<Response> getMyStats() => get('/auth/stats');
  Future<Response> updateProfile(Map<String, dynamic> data) =>
      put('/auth/profile', data: data);

  // ── Events ──
  Future<Response> getEvents({
    int page = 1,
    int pageSize = 10,
    int? categoryId,
    int? cityId,
    int? organizationId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
    String? status,
  }) {
    return get(ApiConfig.events, queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (categoryId != null) 'categoryId': categoryId,
      if (cityId != null) 'cityId': cityId,
      if (organizationId != null) 'organizationId': organizationId,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
      if (query != null && query.isNotEmpty) 'query': query,
      if (status != null) 'status': status,
    });
  }

  Future<Response> getEventById(int id) => get('${ApiConfig.events}/$id');

  // ── Recommendations ──
  Future<Response> getRecommendedEvents({int top = 5}) =>
      get('${ApiConfig.events}/recommended', queryParameters: {'top': top});

  // ── Shifts ──
  Future<Response> getShiftsByEvent(int eventId) =>
      get(ApiConfig.shifts, queryParameters: {'eventId': eventId});

  // ── Shift Registrations ──
  Future<Response> registerForShift(int shiftId) =>
      post('${ApiConfig.shiftRegistrations}/register/$shiftId');
  Future<Response> checkIn(int shiftId) =>
      post('${ApiConfig.shiftRegistrations}/checkin/$shiftId');
  Future<Response> checkOut(int shiftId) =>
      post('${ApiConfig.shiftRegistrations}/checkout/$shiftId');
  Future<Response> getMyShifts() =>
      get('${ApiConfig.shiftRegistrations}/my-shifts');

  // ── Campaigns ──
  Future<Response> getCampaigns({int page = 1, int pageSize = 3}) =>
      get(ApiConfig.campaigns,
          queryParameters: {'page': page, 'pageSize': pageSize});
  Future<Response> getCampaign(int id) => get('${ApiConfig.campaigns}/$id');

  // ── Donations ──
  Future<Response> createDonation(Map<String, dynamic> data) =>
      post(ApiConfig.donations, data: data);
  Future<Response> getDonationsByCampaign(int campaignId) =>
      get('${ApiConfig.donations}/by-campaign/$campaignId');
  Future<Response> createPaymentIntent(Map<String, dynamic> data) =>
      post('${ApiConfig.donations}/create-payment-intent', data: data);
  Future<Response> getRecentDonations({int count = 10}) =>
      get('${ApiConfig.donations}/recent', queryParameters: {'count': count});

  // ── Leaderboard ──
  Future<Response> getLeaderboard({int top = 10}) =>
      get(ApiConfig.leaderboard, queryParameters: {'top': top});
  Future<Response> getLeaderboardPaged({int page = 1, int pageSize = 20}) =>
      get('${ApiConfig.leaderboard}/paged',
          queryParameters: {'page': page, 'pageSize': pageSize});

  // ── Blog ──
  Future<Response> getBlogPosts({int page = 1, int pageSize = 10}) =>
      get(ApiConfig.blogPosts,
          queryParameters: {'page': page, 'pageSize': pageSize});
  Future<Response> getBlogPost(int id) => get('${ApiConfig.blogPosts}/$id');

  // ── Categories ──
  Future<Response> getCategories() => get(ApiConfig.categories);
  Future<Response> getCities() => get(ApiConfig.cities);
  Future<Response> getOrganizations({int page = 1, int pageSize = 100}) =>
      get('/organizations',
          queryParameters: {'page': page, 'pageSize': pageSize});

  // ── Notifications ──
  Future<Response> getNotifications() => get(ApiConfig.notifications);
  Future<Response> markNotificationRead(int id) =>
      put('${ApiConfig.notifications}/$id/read');

  // ── Skills ──
  Future<Response> getSkills() => get(ApiConfig.skills);
  Future<Response> getUserSkills() => get('/userskills/my');
  Future<Response> addUserSkill(int skillId) => post('/userskills',
      data: {'skillId': skillId, 'proficiencyLevel': 3, 'yearsExperience': 0});
  Future<Response> removeUserSkill(int id) => delete('/userskills/$id');

  // ── Dashboard ──
  Future<Response> getDashboardStats() => get('${ApiConfig.dashboard}/stats');
}
