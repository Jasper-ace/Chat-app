import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class HomeownerAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register homeowner
  Future<UserCredential?> registerHomeowner({
    required String email,
    required String password,
    required String name,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save to Firestore
      await _firestore.collection('homeowners').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'userType': 'homeowner',
        'createdAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      });

      return credential;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  // Sign in homeowner
  Future<UserCredential?> signInHomeowner({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get homeowner data
  Future<DocumentSnapshot?> getHomeownerData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await _firestore.collection('homeowners').doc(user.uid).get();
  }

  // Update homeowner data
  Future<void> updateHomeownerData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('homeowners').doc(user.uid).update(data);
  }

  // Check if user exists as homeowner
  Future<bool> homeownerExists(String uid) async {
    final doc = await _firestore.collection('homeowners').doc(uid).get();
    return doc.exists;
  }

  // Open chat for homeowner
  void openChat(BuildContext context, int currentUserId) {
    context.push('/chats');
  }
}
