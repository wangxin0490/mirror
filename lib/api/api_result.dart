/// BFF 统一响应（含业务 code）。
class ApiResult<T> {
  ApiResult({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final T? data;

  bool get ok => code == 0;
}
