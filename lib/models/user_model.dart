class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? familyId;
  final int? batteryLevel; // level

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.familyId,
    this.batteryLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'familyId': familyId,
      'batteryLevel': batteryLevel,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      familyId: map['familyId'],
      batteryLevel: map['batteryLevel'], //  Database gtn battry level
    );
  }
}
