import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Register Function (Email Verification )
  Future<User?> registerUser(
      String name, String email, String password, String phone) async {
    try {
      // A. Firebase Auth  User
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // B. Database  'users'  collection
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          familyId: null, // Family
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

        //  Verification Email
        await user.sendEmailVerification();

        //  2  Register  Auto Login Sign Out
        await _auth.signOut();

        return user;
      }
    } catch (e) {
      print("Register Error: $e");
      rethrow;
    }
    return null;
  }

  // Login Function
  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      rethrow;
    }
  }

  //  Sign Out Function
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
