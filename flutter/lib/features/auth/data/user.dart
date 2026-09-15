import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    this.bio = '',
    this.photoUrl = '',
    required this.role,
    required this.isVerified,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String username;
  final String bio;

  @JsonKey(name: 'photo_url')
  final String photoUrl;
  final String role;

  @JsonKey(name: 'is_verified')
  final bool isVerified;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? bio,
    String? photoUrl,
    String? role,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}