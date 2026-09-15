// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  bio: json['bio'] as String? ?? '',
  photoUrl: json['photo_url'] as String? ?? '',
  role: json['role'] as String,
  isVerified: json['is_verified'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'username': instance.username,
  'bio': instance.bio,
  'photo_url': instance.photoUrl,
  'role': instance.role,
  'is_verified': instance.isVerified,
  'created_at': instance.createdAt.toIso8601String(),
};
