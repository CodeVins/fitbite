/// 서버 ProblemDetail(code, detail) 또는 네트워크 실패를 나타낸다.
/// 네트워크 실패는 status == null, code == 'NETWORK'.
class ApiError implements Exception {
  final int? status;
  final String code;
  final String message;

  const ApiError(this.status, this.code, this.message);

  @override
  String toString() => 'ApiError($status, $code, $message)';
}
