# Dual Storage Integration Guide

This guide explains how to integrate Laravel MySQL database with Flutter apps while maintaining Firebase for authentication and real-time updates.

## Overview

The dual storage system provides:
- **Firebase**: Real-time chat functionality and authentication
- **Laravel MySQL**: Data persistence, analytics, and advanced querying
- **Auto-sync**: Keeps both systems synchronized

## Architecture

```
Flutter App → Firebase Auth → Laravel API → MySQL + Firebase
                                    ↓
                            Both systems updated
```

## Setup Instructions

### 1. Laravel Backend Setup

The Laravel backend is already configured with:
- ✅ Homeowner and Tradie models with Firebase UID mapping
- ✅ Message and Chat models for dual storage
- ✅ API endpoints for all operations
- ✅ Firebase service for auto-sync
- ✅ Comprehensive error handling

**Key API Endpoints:**
```
POST /api/homeowners          - Create homeowner
POST /api/tradies             - Create tradie
POST /api/chats/send-message  - Send message (dual storage)
GET  /api/chats/user-chats    - Get user chats
POST /api/chats/mark-as-read  - Mark messages as read
POST /api/tradies/search      - Search tradies
```

### 2. Flutter Integration

#### A. Add Dependencies

Add to your `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
  dio: ^5.4.0  # For homeowner app
  firebase_core: ^4.1.1
  cloud_firestore: ^6.0.2
  firebase_auth: ^6.1.0
```

#### B. Use the Dual Storage Service

**For fixo_chat (shared module):**
```dart
import 'package:fixo_chat/services/dual_storage_service.dart';

final dualStorage = DualStorageService();

// Register user (saves to both Firebase and Laravel)
await dualStorage.registerUser(
  email: email,
  password: password,
  firstName: firstName,
  lastName: lastName,
  userType: 'homeowner', // or 'tradie'
  phone: phone,
  address: address,
  // ... other fields
);

// Send message (saves to both systems)
await dualStorage.sendMessage(
  receiverId: receiverUid,
  message: message,
  senderUserType: 'homeowner',
  receiverUserType: 'tradie',
);
```

**For homeowner app:**
```dart
import 'package:homeowner/services/dual_storage_integration.dart';

final integration = DualStorageIntegration();

// Register homeowner
await integration.registerHomeowner(
  email: email,
  password: password,
  firstName: firstName,
  lastName: lastName,
  // ... other fields
);

// Send message to tradie
await integration.sendMessageToTradie(
  tradieFirebaseUid: tradieUid,
  message: message,
);

// Get available tradies
final tradies = await integration.getAvailableTradies(
  latitude: userLat,
  longitude: userLng,
  radius: 50, // km
);
```

### 3. Configuration

#### Update Laravel API URL

In `fixo_chat/lib/services/laravel_api_service.dart`:
```dart
static const String baseUrl = 'https://your-domain.com/api';
```

In `homeowner/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'https://your-domain.com/api';
```

#### Firebase Configuration

Ensure your Firebase project is properly configured in both apps:
- `firebase_options.dart` files are up to date
- Firebase project ID matches in Laravel `.env`

## Usage Examples

### 1. User Registration

**Enhanced Registration (fixo_chat):**
```dart
// In your registration widget
final dualStorage = DualStorageService();

try {
  final result = await dualStorage.registerUser(
    email: emailController.text,
    password: passwordController.text,
    firstName: firstNameController.text,
    lastName: lastNameController.text,
    userType: 'homeowner',
    phone: phoneController.text,
    address: addressController.text,
    city: cityController.text,
    region: regionController.text,
    // Tradie-specific fields (if userType is 'tradie')
    tradeType: tradeTypeController.text,
    businessName: businessNameController.text,
    yearsExperience: int.tryParse(experienceController.text),
    hourlyRate: double.tryParse(rateController.text),
  );

  if (result?.user != null) {
    // Registration successful - user saved to both Firebase and Laravel
    Navigator.pushReplacement(context, /* next screen */);
  }
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Registration failed: $e')),
  );
}
```

### 2. Sending Messages

**Real-time Chat with Dual Storage:**
```dart
// In your chat widget
final dualStorage = DualStorageService();

Future<void> sendMessage(String message) async {
  try {
    final success = await dualStorage.sendMessage(
      receiverId: otherUserUid,
      message: message,
      senderUserType: 'homeowner',
      receiverUserType: 'tradie',
      metadata: {
        'sent_from': 'mobile_app',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (!success) {
      // Handle error
      showErrorSnackBar('Failed to send message');
    }
  } catch (e) {
    showErrorSnackBar('Error: $e');
  }
}

// Listen to real-time updates from Firebase
StreamBuilder(
  stream: chatService.getMessages(otherUserUid),
  builder: (context, snapshot) {
    // Build your message list UI
    return ListView.builder(/* ... */);
  },
)
```

### 3. Searching Tradies

**Location-based Search:**
```dart
// In homeowner app
final integration = DualStorageIntegration();

Future<void> searchNearbyTradies() async {
  try {
    final tradies = await integration.getAvailableTradies(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      radius: 25, // 25km radius
      serviceType: 'plumber', // optional filter
    );

    if (tradies != null) {
      setState(() {
        availableTradies = tradies;
      });
    }
  } catch (e) {
    showErrorSnackBar('Failed to search tradies: $e');
  }
}
```

### 4. Chat Statistics

**Analytics Dashboard:**
```dart
// Get comprehensive chat statistics
final stats = await dualStorage.getChatStats();

if (stats != null) {
  print('Total chats: ${stats['total_chats']}');
  print('Messages sent: ${stats['total_messages_sent']}');
  print('Messages received: ${stats['total_messages_received']}');
  print('Unread messages: ${stats['unread_messages']}');
  print('Active chats today: ${stats['active_chats_today']}');
}
```

## Benefits

### Real-time Features (Firebase)
- ✅ Instant message delivery
- ✅ Live typing indicators
- ✅ Offline support
- ✅ Push notifications
- ✅ Real-time user presence

### Data Management (Laravel MySQL)
- ✅ Complex queries and joins
- ✅ Advanced search and filtering
- ✅ Business analytics and reporting
- ✅ Data backup and recovery
- ✅ Admin panel management
- ✅ User behavior tracking

### Dual Storage Advantages
- ✅ **Redundancy**: Data safety with two systems
- ✅ **Performance**: Real-time UI + efficient queries
- ✅ **Scalability**: Best of both worlds
- ✅ **Analytics**: Rich reporting capabilities
- ✅ **Flexibility**: Use the right tool for each task

## Error Handling

The system includes comprehensive error handling:

```dart
try {
  await dualStorage.sendMessage(/* ... */);
} catch (e) {
  if (e.toString().contains('network')) {
    // Handle network errors
    showRetryDialog();
  } else if (e.toString().contains('auth')) {
    // Handle authentication errors
    redirectToLogin();
  } else {
    // Handle other errors
    showGenericError();
  }
}
```

## Monitoring

### Laravel Logs
Check Laravel logs for sync operations:
```bash
tail -f storage/logs/laravel.log | grep "Firebase\|Message\|Chat"
```

### Firebase Console
Monitor real-time database usage and authentication in Firebase Console.

### Database Queries
Use Laravel's query log to monitor database performance:
```php
DB::enableQueryLog();
// Your operations
dd(DB::getQueryLog());
```

## Troubleshooting

### Common Issues

1. **Messages not syncing to Laravel**
   - Check Laravel API URL configuration
   - Verify Firebase UID mapping in database
   - Check network connectivity

2. **Real-time updates not working**
   - Verify Firebase configuration
   - Check Firestore security rules
   - Ensure proper collection structure

3. **User registration failing**
   - Check required field validation
   - Verify unique constraints (email, firebase_uid)
   - Check Laravel error logs

### Debug Mode

Enable debug logging:
```dart
// In your app initialization
if (kDebugMode) {
  print('Debug mode enabled - detailed logging active');
}
```

## Production Deployment

### Security Checklist
- [ ] Update API URLs to production endpoints
- [ ] Configure proper CORS settings in Laravel
- [ ] Set up SSL certificates
- [ ] Configure Firebase security rules
- [ ] Enable Laravel rate limiting
- [ ] Set up proper error monitoring

### Performance Optimization
- [ ] Enable Laravel caching
- [ ] Configure database indexes
- [ ] Set up CDN for static assets
- [ ] Optimize Firebase queries
- [ ] Implement proper pagination

This dual storage system provides a robust foundation for your chat application with the benefits of both real-time functionality and comprehensive data management.