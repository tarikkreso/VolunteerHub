import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _token;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String? get token => _token;

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  // ── Auth ──
  Future<Response> login(String email, String password) =>
      _dio.post(ApiConfig.login, data: {'email': email, 'password': password});

  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/auth/register', data: data);

  Future<Response> getMe() => _dio.get('/auth/me');
  Future<Response> getMyStats() => _dio.get('/auth/stats');
  Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.put('/auth/profile', data: data);

  // ── Events ──
  Future<Response> getEvents({Map<String, dynamic>? query}) =>
      _dio.get(ApiConfig.events, queryParameters: query);

  Future<Response> getEvent(int id) => _dio.get('${ApiConfig.events}/$id');

  Future<Response> createEvent(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.events, data: data);

  Future<Response> updateEvent(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.events}/$id', data: data);

  Future<Response> deleteEvent(int id) =>
      _dio.delete('${ApiConfig.events}/$id');

  // ── Shifts ──
  Future<Response> getShifts({int? eventId}) => _dio.get(ApiConfig.shifts,
      queryParameters: eventId != null ? {'eventId': eventId} : null);

  Future<Response> createShift(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.shifts, data: data);

  Future<Response> updateShift(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.shifts}/$id', data: data);

  Future<Response> deleteShift(int id) =>
      _dio.delete('${ApiConfig.shifts}/$id');

  // ── Shift Registrations ──
  Future<Response> getShiftRegistrations(int shiftId) =>
      _dio.get('${ApiConfig.shiftRegistrations}/by-shift/$shiftId');

  Future<Response> approveRegistration(int id,
          {double? hours, String? notes}) =>
      _dio.put('${ApiConfig.shiftRegistrations}/$id/approve',
          data: {'approvedHours': hours, 'adminNotes': notes});

  Future<Response> rejectRegistration(int id, {String? reason}) =>
      _dio.put('${ApiConfig.shiftRegistrations}/$id/reject',
          data: {'adminNotes': reason});

  Future<Response> finalApproval(int shiftId) =>
      _dio.post('${ApiConfig.shiftRegistrations}/final-approval/$shiftId');

  Future<Response> approveAll(int shiftId) =>
      _dio.post('${ApiConfig.shiftRegistrations}/approve-all/$shiftId');

  // ── Users / Volunteers ──
  Future<Response> getUsers({Map<String, dynamic>? query}) =>
      _dio.get(ApiConfig.users, queryParameters: query);

  Future<Response> getUser(int id) => _dio.get('${ApiConfig.users}/$id');

  Future<Response> updateUser(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.users}/$id', data: data);

  Future<Response> getUserStats(int id) =>
      _dio.get('${ApiConfig.users}/$id/stats');

  // ── Campaigns ──
  Future<Response> getCampaigns({int pageSize = 20}) =>
      _dio.get(ApiConfig.campaigns, queryParameters: {'pageSize': pageSize});
  Future<Response> getCampaign(int id) =>
      _dio.get('${ApiConfig.campaigns}/$id');

  Future<Response> createCampaign(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.campaigns, data: data);

  Future<Response> updateCampaign(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.campaigns}/$id', data: data);

  Future<Response> deleteCampaign(int id) =>
      _dio.delete('${ApiConfig.campaigns}/$id');

  // ── Donations ──
  Future<Response> getDonationsByCampaign(int campaignId) =>
      _dio.get('${ApiConfig.donations}/by-campaign/$campaignId');

  Future<Response> getDonations({int? campaignId}) {
    if (campaignId != null) {
      return getDonationsByCampaign(campaignId);
    }
    return _dio.get('${ApiConfig.donations}/recent');
  }

  // ── Blog ──
  Future<Response> getBlogPosts() => _dio.get(ApiConfig.blogPosts);
  Future<Response> getBlogPostsAll() => _dio.get('${ApiConfig.blogPosts}/all');
  Future<Response> getBlogPost(int id) =>
      _dio.get('${ApiConfig.blogPosts}/$id');

  Future<Response> createBlogPost(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.blogPosts, data: data);

  Future<Response> updateBlogPost(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.blogPosts}/$id', data: data);

  Future<Response> deleteBlogPost(int id) =>
      _dio.delete('${ApiConfig.blogPosts}/$id');

  // ── Leaderboard ──
  Future<Response> getLeaderboard({int top = 20}) =>
      _dio.get(ApiConfig.leaderboard, queryParameters: {'top': top});

  // ── Dashboard ──
  Future<Response> getDashboardStats(
          {DateTime? startDate, DateTime? endDate}) =>
      _dio.get(
        ApiConfig.dashboard,
        queryParameters: {
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
      );

  // ── User Skills ──
  Future<Response> getUserSkills(int userId) =>
      _dio.get('${ApiConfig.userSkills}/$userId');

  Future<Response> getUserShiftRegistrations(int userId) =>
      _dio.get('${ApiConfig.shiftRegistrations}/by-user/$userId');

  // ── Reference Data ──
  Future<Response> getCategories() => _dio.get(ApiConfig.categories);
  Future<Response> getCities() => _dio.get(ApiConfig.cities);
  Future<Response> getCountries() => _dio.get(ApiConfig.countries);
  Future<Response> getSkills() => _dio.get(ApiConfig.skills);

  Future<Response> createCategory(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.categories, data: data);

  Future<Response> updateCategory(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.categories}/$id', data: data);

  Future<Response> deleteCategory(int id) =>
      _dio.delete('${ApiConfig.categories}/$id');

  Future<Response> createCountry(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.countries, data: data);

  Future<Response> updateCountry(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.countries}/$id', data: data);

  Future<Response> deleteCountry(int id) =>
      _dio.delete('${ApiConfig.countries}/$id');

  Future<Response> createCity(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.cities, data: data);

  Future<Response> updateCity(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.cities}/$id', data: data);

  Future<Response> deleteCity(int id) =>
      _dio.delete('${ApiConfig.cities}/$id');

  Future<Response> createSkill(Map<String, dynamic> data) =>
      _dio.post(ApiConfig.skills, data: data);

  Future<Response> updateSkill(int id, Map<String, dynamic> data) =>
      _dio.put('${ApiConfig.skills}/$id', data: data);

  Future<Response> deleteSkill(int id) =>
      _dio.delete('${ApiConfig.skills}/$id');

  // ── Leaderboard Paged ──
  Future<Response> getLeaderboardPaged({int page = 1, int pageSize = 20}) =>
      _dio.get('${ApiConfig.leaderboard}/paged',
          queryParameters: {'page': page, 'pageSize': pageSize});

  // ── Reports ──
  Future<Response> getVolunteerParticipationReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _dio.get(
        '/reports/volunteer-participation',
        queryParameters: {
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
      );

  Future<Response> getHoursByVolunteerReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _dio.get(
        '/reports/hours-by-volunteer',
        queryParameters: {
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
      );

  Future<Response> getEventAttendanceReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _dio.get(
        '/reports/event-attendance',
        queryParameters: {
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
      );

  Future<Response> getDonationsSummaryReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _dio.get(
        '/reports/donations-summary',
        queryParameters: {
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
      );
}
