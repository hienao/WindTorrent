enum BackupFailureReason { parseFailed, fileAccess, unknown }

class BackupException implements Exception {
  const BackupException({required this.reason, this.message, this.statusCode});

  final BackupFailureReason reason;
  final String? message;
  final int? statusCode;

  @override
  String toString() {
    final parts = <String>['BackupException(${reason.name})'];
    if (statusCode != null) {
      parts.add('status=$statusCode');
    }
    if (message != null && message!.trim().isNotEmpty) {
      parts.add(message!.trim());
    }
    return parts.join(': ');
  }
}
