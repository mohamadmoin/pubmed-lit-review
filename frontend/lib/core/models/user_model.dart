import 'dart:convert';

/// User model that integrates with both the authentication system and project components
class UserModel {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? institution;
  final List<String> areasOfExpertise;
  final List<String> publications;
  final Map<String, dynamic>? additionalData;
  final String? profileSlug;

  /// Computed property for display name
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName'.trim();
    } else if (firstName != null) {
      return firstName!;
    } else {
      return username;
    }
  }

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.institution,
    this.areasOfExpertise = const [],
    this.publications = const [],
    this.additionalData,
    this.profileSlug,
  });

  /// Create a User from auth service response
  factory UserModel.fromAuthJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] ?? json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      // Other fields may not be present in auth response
      areasOfExpertise: [],
      publications: [],
      profileSlug: json['profile_slug'],
    );
  }

  /// Create a User from project service response
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final List<String> expertise = [];
    if (json['areas_of_expertise'] != null) {
      expertise.addAll((json['areas_of_expertise'] as List).map((e) => e.toString()));
    } else if (json['expertise'] != null) {
      expertise.addAll((json['expertise'] as List).map((e) => e.toString()));
    }

    final List<String> pubs = [];
    if (json['publications'] != null) {
      pubs.addAll((json['publications'] as List).map((e) => e.toString()));
    }

    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      avatarUrl: json['avatar_url'] ?? json['avatar'],
      institution: json['institution'],
      areasOfExpertise: expertise,
      publications: pubs,
      additionalData: json['profile_data'] is String
          ? jsonDecode(json['profile_data'])
          : (json['profile_data'] as Map<String, dynamic>?),
      profileSlug: json['profile_slug'],
    );
  }

  /// Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (institution != null) 'institution': institution,
      'areas_of_expertise': areasOfExpertise,
      'publications': publications,
      if (additionalData != null) 'profile_data': additionalData,
    };
  }

  /// Create a copy of this user with some properties changed
  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? institution,
    List<String>? areasOfExpertise,
    List<String>? publications,
    Map<String, dynamic>? additionalData,
    String? profileSlug,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      institution: institution ?? this.institution,
      areasOfExpertise: areasOfExpertise ?? this.areasOfExpertise,
      publications: publications ?? this.publications,
      additionalData: additionalData ?? this.additionalData,
      profileSlug: profileSlug ?? this.profileSlug,
    );
  }
}
