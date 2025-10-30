import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/user_model.dart';
import '../services/tradie_auth_service.dart';

// Firebase Auth state
class FirebaseAuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final UserModel? userData;
  final String? error;

  const FirebaseAuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.userData,
    this.error,
  });

  FirebaseAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? user,
    UserModel? userData,
    String? error,
  }) {
    return FirebaseAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      userData: userData ?? this.userData,
      error: error,
    );
  }
}

// Firebase Auth ViewModel
class FirebaseAuthViewModel extends StateNotifier<FirebaseAuthState> {
  final TradieAuthService _authService;

  FirebaseAuthViewModel(this._authService) : super(const FirebaseAuthState()) {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await _authService.getTradieData();
        UserModel? userData;
        if (userDoc != null && userDoc.exists) {
          userData = UserModel.fromFirestore(userDoc);
        }

        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          userData: userData,
        );
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          user: null,
          userData: null,
        );
      }
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String tradeType,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.registerTradie(
        email: email,
        password: password,
        name: name,
        tradeType: tradeType,
        phone: phone,
      );

      if (result != null) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Registration failed');
        return false;
      }
    } catch (e) {
      // Check if this is the known type casting error but user was actually created
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        print(
          '⚠️ Known Firebase Auth plugin error, checking if user was created...',
        );

        // Wait a moment for Firebase to process
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if user was actually created despite the error
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.email == email) {
          print('✅ User was created successfully despite plugin error');

          // Try to create the Firestore document manually
          try {
            // Get proper auto-increment ID
            final homeownersSnapshot = await FirebaseFirestore.instance
                .collection('homeowners')
                .get();
            final tradiesSnapshot = await FirebaseFirestore.instance
                .collection('tradies')
                .get();

            int highestId = 0;
            for (final doc in homeownersSnapshot.docs) {
              final data = doc.data();
              final id = data['id'] as int? ?? 0;
              if (id > highestId) highestId = id;
            }
            for (final doc in tradiesSnapshot.docs) {
              final data = doc.data();
              final id = data['id'] as int? ?? 0;
              if (id > highestId) highestId = id;
            }
            final nextId = highestId + 1;

            await FirebaseFirestore.instance
                .collection('tradies')
                .doc(currentUser.uid)
                .set({
                  'id': nextId,
                  'autoId': nextId, // Add autoId field for thread service
                  'name': name,
                  'email': email,
                  'userType': 'tradie',
                  'tradeType': tradeType,
                  'phone': phone ?? '',
                  'bio': '',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

            print('✅ Firestore document created manually');
            state = state.copyWith(isLoading: false);
            return true;
          } catch (firestoreError) {
            print('❌ Failed to create Firestore document: $firestoreError');
            state = state.copyWith(
              isLoading: false,
              error: 'User created but profile setup failed',
            );
            return false;
          }
        }
      }

      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.signInTradie(
        email: email,
        password: password,
      );

      if (result != null) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Login failed');
        return false;
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Invalid account type')) {
        errorMessage = 'Invalid account type. Please check your credentials.';
      } else if (errorMessage.contains('user-not-found')) {
        errorMessage = 'No user found with this email.';
      } else if (errorMessage.contains('wrong-password')) {
        errorMessage = 'Incorrect password.';
      } else if (errorMessage.contains('invalid-email')) {
        errorMessage = 'Invalid email address.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
      state = const FirebaseAuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void openChat(BuildContext context, int currentUserId) {
    _authService.openChat(context, currentUserId);
  }
}

// Providers
final tradieAuthServiceProvider = Provider<TradieAuthService>((ref) {
  return TradieAuthService();
});

final firebaseAuthViewModelProvider =
    StateNotifierProvider<FirebaseAuthViewModel, FirebaseAuthState>((ref) {
      final authService = ref.watch(tradieAuthServiceProvider);
      return FirebaseAuthViewModel(authService);
    });
