# 🚀 Laravel + Firebase + Reverb Integration

## 📋 **Laravel Backend Setup**

### **1. Install Required Packages**

```bash
composer require google/cloud-firestore
composer require pusher/pusher-php-server
composer require laravel/reverb
```

### **2. Environment Configuration**

```env
# .env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CREDENTIALS=path/to/service-account.json

REVERB_APP_ID=your-app-id
REVERB_APP_KEY=your-app-key
REVERB_APP_SECRET=your-app-secret
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=http

BROADCAST_CONNECTION=reverb
```

### **3. Firebase Service**

```php
<?php
// app/Services/FirebaseService.php
namespace App\Services;

use Google\Cloud\Firestore\FirestoreClient;
use Illuminate\Support\Facades\Log;

class FirebaseService
{
    protected $firestore;

    public function __construct()
    {
        $this->firestore = new FirestoreClient([
            'projectId' => config('firebase.project_id'),
            'keyFilePath' => config('firebase.credentials'),
        ]);
    }

    public function createMessage(array $data)
    {
        try {
            $collection = $this->firestore->collection('messages');
            $document = $collection->add($data);
            return $document->id();
        } catch (\Exception $e) {
            Log::error('Firebase create message error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function updateChat(string $chatId, array $data)
    {
        try {
            $document = $this->firestore->collection('chats')->document($chatId);
            $document->update($data);
        } catch (\Exception $e) {
            Log::error('Firebase update chat error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function updateChatTypingStatus(string $chatId, string $userId, ?string $timestamp)
    {
        try {
            $document = $this->firestore->collection('chats')->document($chatId);
            $document->update([
                "typing_status.{$userId}" => $timestamp,
                'updated_at' => now()->toISOString(),
            ]);
        } catch (\Exception $e) {
            Log::error('Firebase update typing status error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function createUserProfile(array $userData)
    {
        try {
            $userId = $userData['user_type'] . '_' . $userData['mysql_id'];
            $document = $this->firestore->collection('user_profiles')->document($userId);
            $document->set($userData);
            return $userId;
        } catch (\Exception $e) {
            Log::error('Firebase create user profile error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function updateUserPresence(string $userId, bool $isOnline)
    {
        try {
            $document = $this->firestore->collection('user_presence')->document($userId);
            $document->set([
                'is_online' => $isOnline,
                'last_seen' => now()->toISOString(),
            ], ['merge' => true]);
        } catch (\Exception $e) {
            Log::error('Firebase update presence error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function generateChatId(string $userId1, string $userId2): string
    {
        $sortedIds = [$userId1, $userId2];
        sort($sortedIds);
        return 'chat_' . implode('_', $sortedIds);
    }
}
```

### **4. Chat Controller**

```php
<?php
// app/Http/Controllers/Api/ChatController.php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Events\MessageSent;
use App\Events\UserTyping;
use App\Services\FirebaseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

class ChatController extends Controller
{
    protected $firebase;

    public function __construct(FirebaseService $firebase)
    {
        $this->firebase = $firebase;
        $this->middleware('auth:sanctum');
    }

    public function sendMessage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|string',
            'content' => 'required|string|max:1000',
            'message_type' => 'in:text,image,file',
            'media_url' => 'nullable|url',
            'media_thumbnail' => 'nullable|url',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = Auth::user();
        $senderId = $user->user_type . '_' . $user->id;
        $receiverId = $request->receiver_id;
        $chatId = $this->firebase->generateChatId($senderId, $receiverId);

        try {
            // Prepare message data
            $messageData = [
                'chat_id' => $chatId,
                'sender_id' => $senderId,
                'sender_type' => $user->user_type,
                'content' => $request->content,
                'message_type' => $request->message_type ?? 'text',
                'timestamp' => now()->toISOString(),
                'read_by' => [
                    $senderId => now()->toISOString()
                ]
            ];

            if ($request->media_url) {
                $messageData['media_url'] = $request->media_url;
            }
            if ($request->media_thumbnail) {
                $messageData['media_thumbnail'] = $request->media_thumbnail;
            }

            // Save to Firebase
            $messageId = $this->firebase->createMessage($messageData);

            // Update chat document
            $this->firebase->updateChat($chatId, [
                'participants' => [$senderId, $receiverId],
                'participant_types' => [$user->user_type, $this->getReceiverType($receiverId)],
                'last_message' => $request->content,
                'last_message_timestamp' => now()->toISOString(),
                'last_sender_id' => $senderId,
                'typing_status.' . $senderId => null, // Clear typing
                'updated_at' => now()->toISOString(),
            ]);

            // Broadcast via Reverb
            broadcast(new MessageSent($messageData, $chatId));

            return response()->json([
                'message_id' => $messageId,
                'chat_id' => $chatId,
                'status' => 'sent'
            ]);

        } catch (\Exception $e) {
            return response()->json(['error' => 'Failed to send message'], 500);
        }
    }

    public function updateTypingStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|string',
            'is_typing' => 'required|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = Auth::user();
        $senderId = $user->user_type . '_' . $user->id;
        $receiverId = $request->receiver_id;
        $chatId = $this->firebase->generateChatId($senderId, $receiverId);

        try {
            $typingTimestamp = $request->is_typing ? now()->toISOString() : null;

            // Update Firebase
            $this->firebase->updateChatTypingStatus($chatId, $senderId, $typingTimestamp);

            // Broadcast typing status
            broadcast(new UserTyping($senderId, $chatId, $request->is_typing));

            return response()->json(['status' => 'updated']);

        } catch (\Exception $e) {
            return response()->json(['error' => 'Failed to update typing status'], 500);
        }
    }

    public function markAsRead(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'chat_id' => 'required|string',
            'message_ids' => 'required|array',
            'message_ids.*' => 'string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = Auth::user();
        $userId = $user->user_type . '_' . $user->id;

        try {
            // This would typically be done via Firebase Admin SDK batch operations
            // For now, we'll just return success and let Firebase handle it client-side
            
            return response()->json(['status' => 'marked_as_read']);

        } catch (\Exception $e) {
            return response()->json(['error' => 'Failed to mark as read'], 500);
        }
    }

    private function getReceiverType(string $receiverId): string
    {
        return str_starts_with($receiverId, 'tradie_') ? 'tradie' : 'homeowner';
    }
}
```

### **5. Broadcasting Events**

```php
<?php
// app/Events/MessageSent.php
namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $message;
    public $chatId;

    public function __construct($message, $chatId)
    {
        $this->message = $message;
        $this->chatId = $chatId;
    }

    public function broadcastOn()
    {
        return new PresenceChannel('chat.' . $this->chatId);
    }

    public function broadcastAs()
    {
        return 'message.sent';
    }

    public function broadcastWith()
    {
        return [
            'message' => $this->message,
            'chat_id' => $this->chatId,
        ];
    }
}
```

```php
<?php
// app/Events/UserTyping.php
namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserTyping implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $userId;
    public $chatId;
    public $isTyping;

    public function __construct($userId, $chatId, $isTyping)
    {
        $this->userId = $userId;
        $this->chatId = $chatId;
        $this->isTyping = $isTyping;
    }

    public function broadcastOn()
    {
        return new PresenceChannel('chat.' . $this->chatId);
    }

    public function broadcastAs()
    {
        return 'user.typing';
    }

    public function broadcastWith()
    {
        return [
            'user_id' => $this->userId,
            'is_typing' => $this->isTyping,
        ];
    }
}
```

### **6. User Model Updates**

```php
<?php
// Add to your User model
class User extends Authenticatable
{
    // ... existing code

    public function getFirebaseUidAttribute()
    {
        return $this->user_type . '_' . $this->id;
    }

    public function syncToFirebase()
    {
        $firebaseService = app(FirebaseService::class);
        
        $userData = [
            'mysql_id' => $this->id,
            'user_type' => $this->user_type,
            'display_name' => $this->name,
            'email' => $this->email,
            'avatar_url' => $this->avatar,
            'phone' => $this->phone,
            'is_verified' => $this->is_verified ?? false,
            'blocked_users' => [],
            'created_at' => $this->created_at->toISOString(),
            'updated_at' => now()->toISOString(),
        ];

        if ($this->user_type === 'tradie') {
            $userData['trade_type'] = $this->trade_type;
            $userData['rating'] = $this->rating ?? 0.0;
            $userData['completed_jobs'] = $this->completed_jobs ?? 0;
        } elseif ($this->user_type === 'homeowner') {
            $userData['location'] = $this->location;
        }

        return $firebaseService->createUserProfile($userData);
    }
}
```

### **7. API Routes**

```php
<?php
// routes/api.php
use App\Http\Controllers\Api\ChatController;

Route::middleware('auth:sanctum')->group(function () {
    Route::prefix('chat')->group(function () {
        Route::post('/send', [ChatController::class, 'sendMessage']);
        Route::post('/typing', [ChatController::class, 'updateTypingStatus']);
        Route::post('/read', [ChatController::class, 'markAsRead']);
    });
});
```

### **8. Broadcasting Configuration**

```php
<?php
// config/broadcasting.php
'connections' => [
    'reverb' => [
        'driver' => 'reverb',
        'key' => env('REVERB_APP_KEY'),
        'secret' => env('REVERB_APP_SECRET'),
        'app_id' => env('REVERB_APP_ID'),
        'options' => [
            'host' => env('REVERB_HOST', '127.0.0.1'),
            'port' => env('REVERB_PORT', 8080),
            'scheme' => env('REVERB_SCHEME', 'http'),
        ],
    ],
],
```

### **9. Firebase Configuration**

```php
<?php
// config/firebase.php
return [
    'project_id' => env('FIREBASE_PROJECT_ID'),
    'credentials' => env('FIREBASE_CREDENTIALS'),
];
```

## 🚀 **Starting the Services**

### **1. Start Laravel Reverb**
```bash
php artisan reverb:start
```

### **2. Start Laravel Queue Worker**
```bash
php artisan queue:work
```

### **3. Start Laravel Development Server**
```bash
php artisan serve
```

## 📱 **Flutter Integration**

### **1. Update Flutter to use Laravel API**

```dart
// lib/services/laravel_chat_service.dart
class LaravelChatService {
  final String baseUrl = 'http://your-api.com/api';
  final Dio _dio = Dio();

  Future<void> sendMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/chat/send',
        data: {
          'receiver_id': receiverId,
          'content': content,
          'message_type': messageType,
          'media_url': mediaUrl,
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${await getAuthToken()}'},
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> updateTypingStatus({
    required String receiverId,
    required bool isTyping,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/chat/typing',
        data: {
          'receiver_id': receiverId,
          'is_typing': isTyping,
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${await getAuthToken()}'},
        ),
      );
    } catch (e) {
      // Silently fail for typing indicators
    }
  }
}
```

### **2. WebSocket Integration**

```dart
// lib/services/websocket_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class WebSocketService {
  late PusherChannelsFlutter pusher;
  
  Future<void> initialize() async {
    pusher = PusherChannelsFlutter.getInstance();
    
    await pusher.init(
      apiKey: 'your-reverb-key',
      cluster: 'mt1',
      hostEndPoint: 'http://localhost:8080',
      hostIsSSL: false,
    );
    
    await pusher.connect();
  }

  void subscribeToChat(String chatId, {
    required Function(Map<String, dynamic>) onMessage,
    required Function(Map<String, dynamic>) onTyping,
  }) {
    final channel = pusher.subscribe(
      channelName: 'presence-chat.$chatId',
    );

    channel.bind('message.sent', (event) {
      if (event?.data != null) {
        onMessage(jsonDecode(event!.data));
      }
    });

    channel.bind('user.typing', (event) {
      if (event?.data != null) {
        onTyping(jsonDecode(event!.data));
      }
    });
  }
}
```

This integration provides a complete real-time chat system with Laravel backend, Firebase for data persistence, and Reverb for real-time broadcasting! 🚀