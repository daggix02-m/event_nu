import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/auth_interceptor.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/data/auth_tokens.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return AuthInterceptor(storage: storage);
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEnvironment.resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const <String, dynamic>{'Accept': 'application/json'},
    ),
  );
  final interceptor = ref.watch(authInterceptorProvider);
  interceptor.attachDio(dio);
  dio.interceptors.add(interceptor);
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(dio: ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final interceptor = ref.watch(authInterceptorProvider);
  interceptor.setRefreshAction((refreshToken) async {
    final data = await api.post(
      '/api/v1/auth/refresh',
      data: <String, String>{'refresh_token': refreshToken},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  });
  return AuthRepository(api);
});