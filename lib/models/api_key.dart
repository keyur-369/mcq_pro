class ApiKey {
  final String id;
  final String name;
  final String key;
  final bool isActive;
  final DateTime createdAt;

  ApiKey({
    required this.id,
    required this.name,
    required this.key,
    required this.isActive,
    required this.createdAt,
  });

  factory ApiKey.fromMap(Map<String, dynamic> map) {
    return ApiKey(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      key: map['api_key'] ?? '',
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'api_key': key,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
