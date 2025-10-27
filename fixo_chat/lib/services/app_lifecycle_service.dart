import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_presence_service.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  final UserPresenceService _presenceService = UserPresenceService();

  void initialize() {
    WidgetsBinding.instance.addObserver(this);

    // Set user online when app starts (if authenticated)
    if (FirebaseAuth.instance.currentUser != null) {
      _presenceService.setUserOnline();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        _presenceService.setUserOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background or closed
        _presenceService.setUserOffline();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        _presenceService.setUserOffline();
        break;
    }
  }
}
