import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart'; // Battery Package
import 'dart:math';
import '../models/family_model.dart';
import '../models/user_model.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Battery _battery = Battery(); // Battery Instance

  // 1. Create Family
  Future<void> createFamily(String familyName) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Invite Code
      String inviteCode = _generateInviteCode();

      FamilyModel newFamily = FamilyModel(
        id: inviteCode,
        name: familyName,
        inviteCode: inviteCode,
        adminId: user.uid,
        members: [user.uid],
      );

      WriteBatch batch = _firestore.batch();

      // Create the Family Document
      DocumentReference familyRef =
          _firestore.collection('families').doc(inviteCode);
      batch.set(familyRef, {
        ...newFamily.toMap(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      //  BATTERY PRASNATAGE
      int currentBattery = 100;
      try {
        currentBattery = await _battery.batteryLevel;
      } catch (e) {}

      // Admin User Profile Update
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);
      batch.set(
        userRef,
        {
          'familyCode': inviteCode,
          'role': 'admin',
          'hasFamily': true,
          'name': user.displayName ?? "Admin",
          'email': user.email,
          'batteryLevel': currentBattery, // 🔥  Battery Field
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // 2. Join Family
  Future<void> joinFamily(String inviteCode) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Invite Code
      DocumentSnapshot familyDoc =
          await _firestore.collection('families').doc(inviteCode).get();

      if (!familyDoc.exists) {
        throw "Invalid Invite Code. Please check and try again.";
      }

      WriteBatch batch = _firestore.batch();

      // NEW FAMILY MEBERS  LSIT
      batch.update(familyDoc.reference, {
        'members': FieldValue.arrayUnion([user.uid])
      });

      // BATTRY PRASNATAGE
      int currentBattery = 100;
      try {
        currentBattery = await _battery.batteryLevel;
      } catch (e) {}

      // Member User Profile UPDATE
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);
      batch.set(
        userRef,
        {
          'familyCode': inviteCode,
          'role': 'member',
          'hasFamily': true,
          'name': user.displayName ?? "Member",
          'email': user.email,
          'batteryLevel': currentBattery,
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Stream for Real-time Family Data
  Stream<FamilyModel?> getMyFamilyStream() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('families')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty
            ? null
            : FamilyModel.fromMap(snapshot.docs.first.data()));
  }

  // Stream for All Family Members
  Stream<List<UserModel>> getFamilyMembers(String familyCode) {
    if (familyCode.isEmpty) return Stream.value([]);

    return _firestore
        .collection('users')
        .where('familyCode', isEqualTo: familyCode)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  // Helper: Generate 6-digit uppercase invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}
