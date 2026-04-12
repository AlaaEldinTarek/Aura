import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  static final CollectionReference _usersCollection =
      _firestore.collection('users');

  // Get user data
  Future<UserData?> getUserData(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Create new user
  Future<void> createUserData(UserData user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to create user data: $e');
    }
  }

  // Update user data
  Future<void> updateUserData(UserData user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _usersCollection.doc(user.uid).update(updatedUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // Update specific fields
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _usersCollection.doc(uid).update({
        ...fields,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user fields: $e');
    }
  }

  // Delete user data
  Future<void> deleteUserData(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }
}
