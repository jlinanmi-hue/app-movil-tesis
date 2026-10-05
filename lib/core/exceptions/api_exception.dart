class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.errors,
  });

  @override
  String toString() => message;
}

/// Excepción cuando el token ha expirado o las credenciales no son válidas (HTTP 401)
class UnauthorizedException extends ApiException {
  UnauthorizedException({
    super.message = 'Sesión expirada o credenciales no válidas.',
    super.data,
  }) : super(statusCode: 401);
}

/// Excepción cuando no hay conexión a internet o el servidor backend Laravel no responde
class NetworkException extends ApiException {
  NetworkException({
    super.message = 'No se pudo conectar con el servidor backend (127.0.0.1:8000 / 10.0.2.2:8000). Asegúrate de que "php artisan serve" esté ejecutándose.',
  }) : super(statusCode: 0);
}

/// Excepción de activación diferida de cuenta de empleado (regla de negocio de Tesis)
class DeferredActivationException extends ApiException {
  final String? fechaIngreso;
  final int? diasRestantes;

  DeferredActivationException({
    required super.message,
    this.fechaIngreso,
    this.diasRestantes,
    super.data,
  }) : super(statusCode: 403);
}
