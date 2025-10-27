# Simplified Firebase Structure

## Overview
The Firebase structure has been simplified to mirror your SQL database with only **2 collections**, removing the separate typing indicator and chat collections for better performance and simpler maintenance.

## Collections

### 1. `threads` Collection
Mirrors your SQL `thread` table with additional real-time features:

```javascript
{
  // Core SQL fields
  "sender_1": 123,                 // int tradies_id from SQL
  "sender_2": 456,                 // int homeowner_id from SQL
  "sender_1_type": "tradie",       // User type identifier
  "sender_2_type": "homeowner",    // User type identifier
  
  // Timestamps
  "created_at": Timestamp,
  "updated_at": Timestamp,
  
  // Last message info
  "last_message": "Hello there!",
  "last_message_time": Timestamp,
  
  // Real-time features (embedded in thread)
  "read_status": {
    "123": true,    // String keys for Firebase, int values in Dart
    "456": false
  },
  "typing_status": {
    "123": Timestamp,  // When user started typing
    "456": null        // Not typing
  },
  "blocked_status": {
    "123": false,
    "456": false
  },
  
  // Thread management
  "is_archived": false
}
```

### 2. `messages` Collection
Mirrors your SQL `messages` table:

```javascript
{
  // Core SQL fields
  "thread_id": "thread_doc_id",    // References thread document
  "sender_id": 123,                // int tradies_id or homeowner_id from SQL
  "content": "Hello there!",       // Message content from SQL
  "date": Timestamp,               // Date field from SQL
  
  // Message features
  "messageType": "text",           // text, image, system
  "imageUrl": null,
  "imageThumbnail": null,
  "read": false,
  "isDeleted": false,
  "isUnsent": false,
  "deletedBy": null                // int userId or null
}
```

## Key Benefits

### 1. **Simplified Structure**
- Only 2 collections instead of 6
- Direct mapping to your SQL database
- Easier to maintain and understand

### 2. **Better Performance**
- Fewer collection reads/writes
- Typing status embedded in threads (no separate collection)
- Reduced Firebase costs

### 3. **SQL Integration**
- `sender_1` and `sender_2` map directly to your SQL `thread` table
- `thread_id`, `sender_id`, `content`, `date` map directly to your SQL `messages` table
- Easy synchronization between Laravel backend and Firebase

### 4. **Real-time Features**
- Typing indicators embedded in thread documents
- Read status tracking per user
- Block status management
- All without separate collections

## Migration Strategy

### From Current Structure
1. **Threads**: Migrate existing chat documents to threads collection
2. **Messages**: Update message documents to use `thread_id` instead of `chat_id`
3. **Typing**: Move typing data into thread documents
4. **Cleanup**: Remove old collections (chats, typing_indicators, etc.)

### SQL Synchronization
1. **Thread Creation**: When creating Firebase thread, sync with Laravel API
2. **Message Sync**: Messages can be synced bidirectionally
3. **ID Mapping**: Maintain mapping between Firebase document IDs and SQL primary keys

## Usage Examples

### Create Thread
```dart
final threadId = await chatService.createOrGetThread(
  user1Id: 123,  // int tradies_id from SQL
  user2Id: 456,  // int homeowner_id from SQL
  user1Type: 'tradie',
  user2Type: 'homeowner',
);
```

### Send Message
```dart
await chatService.sendMessage(
  threadId: threadId,
  senderId: 123,  // int tradies_id or homeowner_id
  content: 'Hello there!',
);
```

### Listen to Messages
```dart
chatService.getMessages(threadId).listen((messages) {
  // Handle real-time message updates
});
```

### Update Typing Status
```dart
await chatService.updateTypingStatus(threadId, 123, true);  // int userId
```

## Security Rules
- Users can only access threads where they are `sender_1` or `sender_2`
- Users can only send messages as themselves (`sender_id` must match auth.uid)
- Messages are readable by thread participants only

## Performance Considerations
- **Indexing**: Create composite indexes for common queries
- **Pagination**: Implement message pagination for large threads
- **Cleanup**: Regularly clean up old typing status timestamps
- **Caching**: Cache thread lists on client side

This simplified structure provides all the real-time chat features while maintaining direct compatibility with your SQL database structure.