class TestBackup {
  final String id;
  final String testId;
  final String? testCode;
  final String? driveFileId;
  final String? driveFolderId;
  final String? drivePath;
  final String filename;
  final String? fileChecksum;
  final String status; // 'pending', 'uploading', 'completed', 'failed', 'needs_configuration'
  final String? errorMessage;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  TestBackup({
    required this.id,
    required this.testId,
    this.testCode,
    this.driveFileId,
    this.driveFolderId,
    this.drivePath,
    required this.filename,
    this.fileChecksum,
    required this.status,
    this.errorMessage,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.completedAt,
    this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending' || status == 'uploading';
  bool get needsConfig => status == 'needs_configuration';
  String? get driveFileName => filename.isNotEmpty ? filename : null;

  factory TestBackup.fromMap(Map<String, dynamic> map) {
    return TestBackup(
      id: map['id'] ?? '',
      testId: map['test_id'] ?? '',
      testCode: map['test_code'],
      driveFileId: map['drive_file_id'],
      driveFolderId: map['drive_folder_id'],
      drivePath: map['drive_path'],
      filename: map['filename'] ?? '',
      fileChecksum: map['file_checksum'],
      status: map['status'] ?? 'pending',
      errorMessage: map['error_message'],
      retryCount: map['retry_count'] ?? 0,
      lastAttemptAt: map['last_attempt_at'] != null ? DateTime.parse(map['last_attempt_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'test_id': testId,
      'test_code': testCode,
      'drive_file_id': driveFileId,
      'drive_folder_id': driveFolderId,
      'drive_path': drivePath,
      'filename': filename,
      'file_checksum': fileChecksum,
      'status': status,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
