class FamilyModel {
  final String id; // Family ID
  final String name; // Family Name (e.g., Perera Home)
  final String inviteCode; //auther cod e
  final String adminId; // made man id
  final List<String> members; // now avalabale IDs

  FamilyModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.adminId,
    required this.members,
  });

  // Data  Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'inviteCode': inviteCode,
      'adminId': adminId,
      'members': members,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Firebase Data, Model
  factory FamilyModel.fromMap(Map<String, dynamic> map) {
    return FamilyModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      adminId: map['adminId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
    );
  }
}
