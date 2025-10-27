import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixo_chat/fixo_chat.dart';
import '../services/homeowner_auth_service.dart';

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
  final HomeownerAuthService _authService;

  FirebaseAuthViewModel(this._authService) : super(const FirebaseAuthState()) {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await _authService.getHomeownerData();
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
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.registerHomeowner(
        email: email,
        password: password,
        name: name,
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
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.signInHomeowner(
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
final homeownerAuthServiceProvider = Provider<HomeownerAuthService>((ref) {
  return HomeownerAuthService();
});

final firebaseAuthViewModelProvider =
    StateNotifierProvider<FirebaseAuthViewModel, FirebaseAuthState>((ref) {
      final authService = ref.watch(homeownerAuthServiceProvider);
      return FirebaseAuthViewModel(authService);
    });
