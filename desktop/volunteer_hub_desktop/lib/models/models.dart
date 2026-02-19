// ---- Auth ----
class LoginResponse {
  final String token;
  final UserDto user;
  LoginResponse({required this.token, required this.user});
  factory LoginResponse.fromJson(Map<String, dynamic> j) =>
      LoginResponse(token: j['token'], user: UserDto.fromJson(j['user']));
}

// ---- User ----
class UserDto {
  final int id;
  final String firstName, lastName, email;
  final String? phone, profileImageUrl, bio, cityName;
  final String role;
  final DateTime createdAt;

  UserDto({required this.id, required this.firstName, required this.lastName,
    required this.email, this.phone, this.profileImageUrl, this.bio,
    this.cityName, required this.role, required this.createdAt});

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
    id: j['id'] ?? 0,
    firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'],
    profileImageUrl: j['profileImageUrl'],
    bio: j['bio'],
    cityName: j['cityName'],
    role: j['role'] ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );

  String get fullName => '$firstName $lastName';
}

class UserStatsDto {
  final double totalHours;
  final int totalEvents, upcomingShifts, rank, points;
  UserStatsDto({required this.totalHours, required this.totalEvents,
    required this.upcomingShifts, required this.rank, required this.points});
  factory UserStatsDto.fromJson(Map<String, dynamic> j) => UserStatsDto(
    totalHours: (j['totalHours'] ?? 0).toDouble(),
    totalEvents: j['totalEvents'] ?? 0,
    upcomingShifts: j['upcomingShifts'] ?? 0,
    rank: j['rank'] ?? 0,
    points: j['points'] ?? 0,
  );
}

// ---- Event ----
class EventDto {
  final int id;
  final String title, description, location;
  final String? imageUrl, cityName;
  final DateTime startDate, endDate;
  final double? latitude, longitude;
  final int maxVolunteers, shiftCount, registeredVolunteers;
  final String status, categoryName;
  final bool isFeatured;
  final DateTime createdAt;

  EventDto({required this.id, required this.title, required this.description,
    this.imageUrl, required this.startDate, required this.endDate,
    required this.location, this.latitude, this.longitude,
    required this.maxVolunteers, required this.status, required this.isFeatured,
    required this.categoryName, this.cityName, required this.shiftCount,
    required this.registeredVolunteers, required this.createdAt});

  factory EventDto.fromJson(Map<String, dynamic> j) => EventDto(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    imageUrl: j['imageUrl'],
    startDate: DateTime.tryParse(j['startDate'] ?? '') ?? DateTime.now(),
    endDate: DateTime.tryParse(j['endDate'] ?? '') ?? DateTime.now(),
    location: j['location'] ?? '',
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    maxVolunteers: j['maxVolunteers'] ?? 0,
    status: j['status'] ?? '',
    isFeatured: j['isFeatured'] ?? false,
    categoryName: j['categoryName'] ?? '',
    cityName: j['cityName'],
    shiftCount: j['shiftCount'] ?? 0,
    registeredVolunteers: j['registeredVolunteers'] ?? 0,
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ---- Shift ----
class ShiftDto {
  final int id, maxVolunteers, currentVolunteers, eventId;
  final String name, eventTitle;
  final String? description;
  final DateTime startTime, endTime, createdAt;
  final bool isLocked;

  ShiftDto({required this.id, required this.name, this.description,
    required this.startTime, required this.endTime,
    required this.maxVolunteers, required this.currentVolunteers,
    required this.isLocked, required this.eventId, required this.eventTitle,
    required this.createdAt});

  factory ShiftDto.fromJson(Map<String, dynamic> j) => ShiftDto(
    id: j['id'] ?? 0,
    name: j['name'] ?? '',
    description: j['description'],
    startTime: DateTime.tryParse(j['startTime'] ?? '') ?? DateTime.now(),
    endTime: DateTime.tryParse(j['endTime'] ?? '') ?? DateTime.now(),
    maxVolunteers: j['maxVolunteers'] ?? 0,
    currentVolunteers: j['currentVolunteers'] ?? 0,
    isLocked: j['isLocked'] ?? false,
    eventId: j['eventId'] ?? 0,
    eventTitle: j['eventTitle'] ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ---- ShiftRegistration ----
class ShiftRegistrationDto {
  final int id, userId, shiftId;
  final String userName, shiftName, status;
  final DateTime? checkInTime, checkOutTime;
  final double? hoursWorked;
  final DateTime createdAt;

  ShiftRegistrationDto({required this.id, required this.userId,
    required this.userName, required this.shiftId, required this.shiftName,
    required this.status, this.checkInTime, this.checkOutTime,
    this.hoursWorked, required this.createdAt});

  factory ShiftRegistrationDto.fromJson(Map<String, dynamic> j) =>
      ShiftRegistrationDto(
        id: j['id'] ?? 0,
        userId: j['userId'] ?? 0,
        userName: j['userName'] ?? '',
        shiftId: j['shiftId'] ?? 0,
        shiftName: j['shiftName'] ?? '',
        status: j['status'] ?? '',
        checkInTime: DateTime.tryParse(j['checkInTime'] ?? ''),
        checkOutTime: DateTime.tryParse(j['checkOutTime'] ?? ''),
        hoursWorked: (j['hoursWorked'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

// ---- Campaign ----
class CampaignDto {
  final int id, donationCount;
  final String title, description;
  final String? imageUrl;
  final double goalAmount, currentAmount, progressPercentage;
  final DateTime startDate, endDate, createdAt;
  final bool isActive, isFeatured;

  CampaignDto({required this.id, required this.title, required this.description,
    this.imageUrl, required this.goalAmount, required this.currentAmount,
    required this.progressPercentage, required this.startDate,
    required this.endDate, required this.isActive, required this.isFeatured,
    required this.donationCount, required this.createdAt});

  factory CampaignDto.fromJson(Map<String, dynamic> j) => CampaignDto(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    imageUrl: j['imageUrl'],
    goalAmount: (j['goalAmount'] ?? 0).toDouble(),
    currentAmount: (j['currentAmount'] ?? 0).toDouble(),
    progressPercentage: (j['progressPercentage'] ?? 0).toDouble(),
    startDate: DateTime.tryParse(j['startDate'] ?? '') ?? DateTime.now(),
    endDate: DateTime.tryParse(j['endDate'] ?? '') ?? DateTime.now(),
    isActive: j['isActive'] ?? false,
    isFeatured: j['isFeatured'] ?? false,
    donationCount: j['donationCount'] ?? 0,
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ---- Donation ----
class DonationDto {
  final int id;
  final double amount;
  final String currency, status, campaignTitle;
  final bool isAnonymous;
  final String? donorName, message;
  final DateTime createdAt;

  DonationDto({required this.id, required this.amount, required this.currency,
    required this.status, required this.isAnonymous, this.donorName,
    this.message, required this.campaignTitle, required this.createdAt});

  factory DonationDto.fromJson(Map<String, dynamic> j) => DonationDto(
    id: j['id'] ?? 0,
    amount: (j['amount'] ?? 0).toDouble(),
    currency: j['currency'] ?? 'BAM',
    status: j['status'] ?? '',
    isAnonymous: j['isAnonymous'] ?? false,
    donorName: j['donorName'],
    message: j['message'],
    campaignTitle: j['campaignTitle'] ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ---- BlogPost ----
class BlogPostDto {
  final int id, viewCount;
  final String title, content;
  final String? summary, imageUrl, tags;
  final bool isPublished;
  final DateTime? publishedAt;
  final String authorName;
  final DateTime createdAt;

  BlogPostDto({required this.id, required this.title, required this.content,
    this.summary, this.imageUrl, this.tags, required this.isPublished,
    this.publishedAt, required this.viewCount, required this.authorName,
    required this.createdAt});

  factory BlogPostDto.fromJson(Map<String, dynamic> j) => BlogPostDto(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    content: j['content'] ?? '',
    summary: j['summary'],
    imageUrl: j['imageUrl'],
    tags: j['tags'],
    isPublished: j['isPublished'] ?? false,
    publishedAt: DateTime.tryParse(j['publishedAt'] ?? ''),
    viewCount: j['viewCount'] ?? 0,
    authorName: j['authorName'] ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ---- Leaderboard ----
class LeaderboardEntryDto {
  final int userId, totalEvents, rank, points;
  final String userName;
  final String? profileImageUrl;
  final double totalHours;

  LeaderboardEntryDto({required this.userId, required this.userName,
    this.profileImageUrl, required this.totalHours, required this.totalEvents,
    required this.rank, required this.points});

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntryDto(
        userId: j['userId'] ?? 0,
        userName: j['userName'] ?? '',
        profileImageUrl: j['profileImageUrl'],
        totalHours: (j['totalHours'] ?? 0).toDouble(),
        totalEvents: j['totalEvents'] ?? 0,
        rank: j['rank'] ?? 0,
        points: j['points'] ?? 0,
      );
}

// ---- Dashboard Stats ----
class DashboardStatsDto {
  final int totalEvents, totalShifts, totalVolunteers, activeCampaigns;
  final double totalHours, totalDonations;

  DashboardStatsDto({required this.totalEvents, required this.totalShifts,
    required this.totalVolunteers, required this.totalHours,
    required this.activeCampaigns, required this.totalDonations});

  factory DashboardStatsDto.fromJson(Map<String, dynamic> j) =>
      DashboardStatsDto(
        totalEvents: j['totalEvents'] ?? 0,
        totalShifts: j['totalShifts'] ?? 0,
        totalVolunteers: j['totalVolunteers'] ?? 0,
        totalHours: (j['totalHours'] ?? 0).toDouble(),
        activeCampaigns: j['activeCampaigns'] ?? 0,
        totalDonations: (j['totalDonations'] ?? 0).toDouble(),
      );
}

// ---- Reference data ----
class EventCategoryDto {
  final int id;
  final String name;
  final String? description, iconUrl, color;
  EventCategoryDto({required this.id, required this.name, this.description, this.iconUrl, this.color});
  factory EventCategoryDto.fromJson(Map<String, dynamic> j) =>
      EventCategoryDto(id: j['id'] ?? 0, name: j['name'] ?? '',
        description: j['description'], iconUrl: j['iconUrl'], color: j['color']);
}

class CityDto {
  final int id;
  final String name;
  final String? postalCode, countryName;
  CityDto({required this.id, required this.name, this.postalCode, this.countryName});
  factory CityDto.fromJson(Map<String, dynamic> j) =>
      CityDto(id: j['id'] ?? 0, name: j['name'] ?? '',
        postalCode: j['postalCode'], countryName: j['countryName']);
}

// ---- Paged result ----
class PagedResult<T> {
  final List<T> items;
  final int totalCount, page, pageSize, totalPages;
  PagedResult({required this.items, required this.totalCount,
    required this.page, required this.pageSize, required this.totalPages});
}
