// lib/exceptions.dart

abstract class AppException implements Exception {
  final String message;
  final String? prefix;
  
  AppException(this.message, {this.prefix});
  
  @override
  String toString() {
    return prefix != null ? "$prefix: $message" : message;
  }
}

// 认证错误 (401)
class AuthException extends AppException {
  AuthException([super.message = "API Key 无效或过期，请检查设置"]);
}

// 网络错误 (超时/无网)
class NetworkException extends AppException {
  NetworkException([super.message = "网络连接失败，请检查网络设置"]);
}

// 业务错误 (API 返回 400/500 等)
class ApiException extends AppException {
  ApiException(super.message);
}