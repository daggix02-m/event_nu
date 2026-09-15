// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_tokens.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthTokens _$AuthTokensFromJson(Map<String, dynamic> json) => AuthTokens(
  accessToken: json['access_token'] as String,
  refreshToken: json['refresh_token'] as String,
  expiresInSeconds: (json['expires_in_seconds'] as num).toInt(),
);

Map<String, dynamic> _$AuthTokensToJson(AuthTokens instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'expires_in_seconds': instance.expiresInSeconds,
    };

VerifiedResponse _$VerifiedResponseFromJson(Map<String, dynamic> json) =>
    VerifiedResponse(verified: json['verified'] as bool);

Map<String, dynamic> _$VerifiedResponseToJson(VerifiedResponse instance) =>
    <String, dynamic>{'verified': instance.verified};
