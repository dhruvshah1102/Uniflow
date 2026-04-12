class AdminModel {
  final String id;
  final String userId;
  final String adminLevel;

  AdminModel({
    required this.id,
    required this.userId,
    required this.adminLevel,
  });

  factory AdminModel.fromMap(Map<String, dynamic> map, String id) {
    return AdminModel(
      id: id,
      userId: map['user_id'] ?? '',
      adminLevel: map['admin_level'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'admin_level': adminLevel,
    };
  }
}
