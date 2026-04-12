import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String themeMode;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserData({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.themeMode,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserData(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      themeMode: data['themeMode'] ?? 'system',
      language: data['language'] ?? 'en',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'themeMode': themeMode,
      'language': language,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create new user with default values
  factory UserData.create({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) {
    final now = DateTime.now();
    return UserData(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      themeMode: 'system',
      language: 'en',
      createdAt: now,
      updatedAt: now,
    );
  }

  // Copy with for updates
  UserData copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? themeMode,
    String? language,
    DateTime? updatedAt,
  }) {
    return UserData(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
