<?php

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Database;
use Illuminate\Support\Facades\Log;

class FirebaseRealtimeDatabaseService
{
    protected $database;

    public function __construct()
    {
        try {
            $credentialsPath = storage_path('app/firebase-credentials.json');
            
            $factory = (new Factory)
                ->withServiceAccount($credentialsPath)
                ->withDatabaseUri(config('firebase.database_url'));

            $this->database = $factory->createDatabase();
        } catch (\Exception $e) {
            Log::error('Firebase Realtime Database initialization failed: ' . $e->getMessage());
            throw $e;
        }
    }



    /**
     * Send message to Firebase Realtime Database
     */
    public function sendMessage(array $messageData)
    {
        try {
            $tradieId = $messageData['sender_type'] === 'tradie' ? $messageData['sender_id'] : $messageData['receiver_id'];
            $homeownerId = $messageData['sender_type'] === 'homeowner' ? $messageData['sender_id'] : $messageData['receiver_id'];

            // Find existing thread or create new one
            $threadId = $this->findExistingThread($tradieId, $homeownerId);
            
            if (!$threadId) {
                // No existing thread, create new one
                $threadId = "thread_{$tradieId}_{$homeownerId}";
                $threadData = [
                    'tradie_id' => $tradieId,
                    'homeowner_id' => $homeownerId,
                    'created_at' => time() * 1000, // Firebase uses milliseconds
                    'last_message_time' => time() * 1000,
                ];

                $this->database->getReference("threads/{$threadId}")
                    ->set($threadData);
                    
                Log::info("Created new thread for message: {$threadId}");
            } else {
                // Update existing thread's last message time
                $this->database->getReference("threads/{$threadId}")
                    ->update(['last_message_time' => time() * 1000]);
                    
                Log::info("Using existing thread for message: {$threadId}");
            }

            // Create message data
            $messageId = 'msg_' . time() . '_' . rand(1000, 9999);
            $message = [
                'sender_id' => $messageData['sender_id'],
                'receiver_id' => $messageData['receiver_id'],
                'sender_type' => $messageData['sender_type'],
                'receiver_type' => $messageData['receiver_type'],
                'content' => $messageData['message'], // Use 'content' field name for Flutter compatibility
                'date' => time() * 1000, // Firebase uses milliseconds
                'read' => false,
            ];

            // Add message to thread
            $this->database->getReference("threads/{$threadId}/messages/{$messageId}")
                ->set($message);

            // Update thread's last message time
            $this->database->getReference("threads/{$threadId}")
                ->update(['last_message_time' => time() * 1000]);

            Log::info("Message sent to Firebase Realtime Database: {$messageId}");

            return [
                'success' => true,
                'thread_id' => $threadId,
                'message_id' => $messageId,
            ];

        } catch (\Exception $e) {
            Log::error("Failed to send message to Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Create or get chat room
     */
    public function createRoom(array $roomData)
    {
        try {
            $tradieId = $roomData['tradie_id'];
            $homeownerId = $roomData['homeowner_id'];
            
            // First, check for existing threads in any format
            $existingThreadId = $this->findExistingThread($tradieId, $homeownerId);
            
            if ($existingThreadId) {
                Log::info("Found existing thread: {$existingThreadId}");
                return [
                    'success' => true,
                    'room_id' => $existingThreadId,
                ];
            }

            // No existing thread found, create new one with new format
            $threadId = "thread_{$tradieId}_{$homeownerId}";
            $threadData = [
                'tradie_id' => $tradieId,
                'homeowner_id' => $homeownerId,
                'created_at' => time() * 1000,
                'last_message_time' => time() * 1000,
            ];

            $this->database->getReference("threads/{$threadId}")
                ->set($threadData);

            Log::info("New thread created: {$threadId}");

            return [
                'success' => true,
                'room_id' => $threadId,
            ];

        } catch (\Exception $e) {
            Log::error("Failed to create room in Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Find existing thread between tradie and homeowner (supports multiple formats)
     */
    private function findExistingThread(int $tradieId, int $homeownerId): ?string
    {
        try {
            // Get all threads
            $allThreads = $this->database->getReference('threads')->getValue();
            
            if (!$allThreads) {
                return null;
            }

            // Look for existing thread with matching tradie_id and homeowner_id
            foreach ($allThreads as $threadId => $threadData) {
                if (is_array($threadData) && 
                    isset($threadData['tradie_id']) && 
                    isset($threadData['homeowner_id']) &&
                    $threadData['tradie_id'] == $tradieId && 
                    $threadData['homeowner_id'] == $homeownerId) {
                    
                    Log::info("Found existing thread: {$threadId} for tradie {$tradieId} and homeowner {$homeownerId}");
                    return $threadId;
                }
            }

            return null;

        } catch (\Exception $e) {
            Log::error("Error finding existing thread: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Block user
     */
    public function blockUser(int $blockerId, int $blockedId)
    {
        try {
            // Add to blocked users list
            $this->database->getReference("userProfiles/{$blockerId}/blockedUsers/{$blockedId}")
                ->set(true);

            Log::info("User {$blockedId} blocked by user {$blockerId}");

            return ['success' => true];

        } catch (\Exception $e) {
            Log::error("Failed to block user in Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Unblock user
     */
    public function unblockUser(int $blockerId, int $blockedId)
    {
        try {
            // Remove from blocked users list
            $this->database->getReference("userProfiles/{$blockerId}/blockedUsers/{$blockedId}")
                ->remove();

            Log::info("User {$blockedId} unblocked by user {$blockerId}");

            return ['success' => true];

        } catch (\Exception $e) {
            Log::error("Failed to unblock user in Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Get messages from a thread
     */
    public function getMessages(string $threadId, int $limit = 50)
    {
        try {
            $messages = $this->database->getReference("threads/{$threadId}/messages")
                ->getValue();

            return [
                'success' => true,
                'messages' => $messages ?? [],
            ];

        } catch (\Exception $e) {
            Log::error("Failed to get messages from Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Mark messages as read
     */
    public function markMessagesAsRead(string $threadId, int $userId)
    {
        try {
            $messages = $this->database->getReference("threads/{$threadId}/messages")->getValue();

            if ($messages) {
                foreach ($messages as $messageId => $message) {
                    // Mark as read if the message was sent to this user
                    if ($message['receiver_id'] == $userId && !$message['read']) {
                        $this->database->getReference("threads/{$threadId}/messages/{$messageId}/read")
                            ->set(true);
                    }
                }
            }

            Log::info("Messages marked as read for user {$userId} in thread {$threadId}");

            return ['success' => true];

        } catch (\Exception $e) {
            Log::error("Failed to mark messages as read in Firebase Realtime Database: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }
}