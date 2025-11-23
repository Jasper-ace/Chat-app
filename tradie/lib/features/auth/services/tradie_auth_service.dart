import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/auth_service.dart';
import '../../chat/widgets/chat_helpers.dart';

class TradieAuthService {
  final AuthService _authService = AuthService();

  // Register tradie
  Future<UserCredential?> registerTradie({
    required String email,
    required String password,
    required String name,
    required String tradeType,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    return await _authService.registerWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
      userType: 'tradie',
      tradeType: tradeType,
      additionalData: additionalData,
    );
  }

  // Sign in tradie
  Future<UserCredential?> signInTradie({
    required String email,
    required String password,
  }) async {
    return await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
      expectedUserType: 'tradie',
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

  // Get tradie data
  Future<DocumentSnapshot?> getTradieData() async {
    return await _authService.getUserData('tradie');
  }

  // Update tradie data
  Future<void> updateTradieData(Map<String, dynamic> data) async {
    await _authService.updateUserData(userType: 'tradie', data: data);
  }

  // Check if user exists as tradie
  Future<bool> tradieExists(String uid) async {
    return await _authService.userExistsInCollection(uid, 'tradie');
  }

  // Open chat for tradie
  void openChat(BuildContext context, int currentUserId) {
    ChatHelpers.openChatList(context, 'tradie', currentUserId);
  }
}
