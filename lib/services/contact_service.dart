import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //  Contact  Add  Function
  Future<void> addContact(String name, String phone) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts') // User  collection
          .add({
        'name': name,
        'phone': phone,
        'addedAt': DateTime.now(),
      });
    } catch (e) {
      print("Error adding contact: $e");
      rethrow;
    }
  }

  // 2. Save  Contacts  Function
  Stream<QuerySnapshot> getContacts() {
    User? user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  // 3. Contact  Delete  Function
  Future<void> deleteContact(String contactId) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }
}
