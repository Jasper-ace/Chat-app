import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/helpers/chat_helpers.dart';

class HomeownerAuthService {
  final AuthService _authService = AuthService();

  // Register homeowner
  Future<UserCredential?> registerHomeowner({
    required String email,
    required String password,
    required String name,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    return await _authService.registerWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
      userType: 'homeowner',
      additionalData: additionalData,
    );
  }

  // Sign in homeowner
  Future<UserCredential?> signInHomeowner({
    required String email,
    required String password,
  }) async {
    return await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
      expectedUserType: 'homeowner',
    );
  }

  // Get current user
  User? get currentUser => _authService.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Get homeowner data
  Future<DocumentSnapshot?> getHomeownerData() async {
    return await _authService.getUserData('homeowner');
  }

  // Update homeowner data
  Future<void> updateHomeownerData(Map<String, dynamic> data) async {
    await _authService.updateUserData(userType: 'homeowner', data: data);
  }

  // Check if user exists as homeowner
  Future<bool> homeownerExists(String uid) async {
    return await _authService.userExistsInCollection(uid, 'homeowner');
  }

  // Open chat for homeowner
  void openChat(BuildContext context, int currentUserId) {
    ChatHelpers.openChatList(context, 'homeowner', currentUserId);
  }
}
