# Firebase Architecture Documentation

## Overview
This document describes the new Firebase-based architecture where fixo_chat serves as the shared Firebase and chat module, while homeowner and tradie apps have separate user collections and role-based authentication.

## Project Structure

```
fixo_chat/                    # Shared Firebase & Chat Module
├── lib/
│   ├── services/
│   │   ├── auth_service.dart         # Shared Firebase Auth
│   │   └── chat_service.dart         # Shared Chat Service
│   ├── models/
│   │   ├── user_model.dart           # User model
│   │   └── message_model.dart        # Message model
│   ├── screens/
│   │   ├── chat_screen.dart          # Individual chat UI
│   │   └── chat_list_screen.dart     # Chat list UI
│   ├── helpers/
│   │   └── chat_helpers.dart         # Helper functions
│   ├── firebase_options.dart         # Firebase config
│   └── fixo_chat.dart               # Main export file

homeowner/                    # Homeowner App
├── lib/
│   ├── features/auth/
│   │   ├── services/
│   │   │   └── homeowner_auth_service.dart
│   │   ├── viewmodels/
│   │   │   └── firebase_auth_viewmodel.dart
│   │   └── views/
│   │       ├── firebase_login_screen.dart
│   │       ├── firebase_register_screen.dart
│   │       └── firebase_dashboard_screen.dart
│   └── main.dart

tradie/                       # Tradie App
├── lib/
│   ├── features/auth/
│   │   ├── services/
│   │   │   └── tradie_auth_service.dart
│   │   ├── viewmodels/
│   │   │   └── firebase_auth_viewmodel.dart
│   │   └── views/
│   │       ├── firebase_login_screen.dart
│   │       ├── firebase_register_screen.dart
│   │       └── firebase_dashboard_screen.dart
│   └── main.dart
```

## Firebase Collections

### User Collections
- `homeowners/{uid}` - Homeowner user data
- `tradies/{uid}` - Tradie user data

### Chat Collections  
- `messages/{messageId}` - All messages with userType filtering
- `chats/{chatId}` - Chat metadata

## Key Features

### Role-Based Authentication
- Homeowners can only register/login as homeowners
- Tradies can only register/login as tradies
- Cross-role validation prevents wrong account types

### Shared Chat System
- Real-time messaging between homeowners and tradies
- Role-based user filtering
- Message history and read status

### Firebase Integration
- Single Firebase project shared across all apps
- Centralized authentication and data management
- Consistent user experience
```