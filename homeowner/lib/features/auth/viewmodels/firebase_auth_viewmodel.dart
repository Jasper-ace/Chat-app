import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/homeowner_api_auth_service.dart';

// Auth state
class FirebaseAuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? userData;
  final String? error;

  const FirebaseAuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userData,
    this.error,
  });

  FirebaseAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? userData,
    String? error,
  }) {
    return FirebaseAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userData: userData ?? this.userData,
      error: error,
    );
  }
}

// Auth ViewModel
class FirebaseAuthViewModel extends StateNotifier<FirebaseAuthState> {
  final HomeownerApiAuthService _authService;

  FirebaseAuthViewModel(this._authService) : super(const FirebaseAuthState()) {
    _init();
  }

  void _init() async {
    // Check if user is already authenticated
    final isAuth = await _authService.isAuthenticated();
    if (isAuth) {
      final userData = await _authService.getCurrentUser();
      state = state.copyWith(isAuthenticated: true, userData: userData);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Call Laravel API for registration
      final result = await _authService.registerHomeowner(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (result != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userData: result['user'],
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Check console for details.',
        );
        return false;
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('SocketException') ||
          errorMsg.contains('Connection refused')) {
        errorMsg =
            'Cannot connect to server. Make sure Laravel is running: php artisan serve';
      } else if (errorMsg.contains('FormatException')) {
        errorMsg = 'Invalid response from server. Check Laravel logs.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
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
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userData: result['user'],
        );
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
}

// Providers
final homeownerAuthServiceProvider = Provider<HomeownerApiAuthService>((ref) {
  return HomeownerApiAuthService();
});

final firebaseAuthViewModelProvider =
    StateNotifierProvider<FirebaseAuthViewModel, FirebaseAuthState>((ref) {
      final authService = ref.watch(homeownerAuthServiceProvider);
      return FirebaseAuthViewModel(authService);
    });
