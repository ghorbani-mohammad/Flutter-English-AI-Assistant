class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final int aiWordCountLimit;
  final String timezone;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    this.aiWordCountLimit = 100, // Default to 100 words
    this.timezone = 'UTC', // Default timezone
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profileImageUrl: json['image'] ?? json['profile_image_url'], // Handle both field names
      aiWordCountLimit: json['ai_word_count_limit'] ?? 100,
      timezone: json['timezone'] ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'image': profileImageUrl, // Use 'image' to match API
      'ai_word_count_limit': aiWordCountLimit,
      'timezone': timezone,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  User copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    int? aiWordCountLimit,
    String? timezone,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      aiWordCountLimit: aiWordCountLimit ?? this.aiWordCountLimit,
      timezone: timezone ?? this.timezone,
    );
  }
} 