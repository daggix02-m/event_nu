import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'auth_tokens.g.dart';

@JsonSerializable()
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
  });

  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  @JsonKey(name: 'expires_in_seconds')
  final int expiresInSeconds;

  DateTime get expiresAt => DateTime.now().add(Duration(seconds: expiresInSeconds));

  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);

  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);
}

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.tokens,
  });

  final User user;
  final AuthTokens tokens;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user': user.toJson(),
        'access_token': tokens.accessToken,
        'refresh_token': tokens.refreshToken,
        'expires_in_seconds': tokens.expiresInSeconds,
      };
}

@JsonSerializable()
class VerifiedResponse {
  const VerifiedResponse({required this.verified});

  final bool verified;

  factory VerifiedResponse.fromJson(Map<String, dynamic> json) =>
      _$VerifiedResponseFromJson(json);

  Map<String, dynamic> toJson() => _$VerifiedResponseToJson(this);
}