<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->string('firebase_message_id')->unique(); // Firebase message ID
            $table->string('firebase_chat_id'); // Firebase chat ID
            $table->unsignedBigInteger('chat_id'); // Laravel chat ID
            $table->string('sender_firebase_uid'); // Firebase UID of sender
            $table->string('receiver_firebase_uid'); // Firebase UID of receiver
            $table->unsignedBigInteger('sender_id')->nullable(); // Laravel sender ID
            $table->unsignedBigInteger('receiver_id')->nullable(); // Laravel receiver ID
            $table->enum('sender_type', ['homeowner', 'tradie']);
            $table->enum('receiver_type', ['homeowner', 'tradie']);
            $table->text('message');
            $table->boolean('is_read')->default(false);
            $table->timestamp('sent_at');
            $table->timestamp('read_at')->nullable();
            $table->json('metadata')->nullable(); // For future extensions (attachments, etc.)
            $table->timestamps();

            // Foreign keys
            $table->foreign('chat_id')->references('id')->on('chats')->onDelete('cascade');

            // Indexes
            $table->index(['firebase_chat_id', 'sent_at']);
            $table->index(['sender_firebase_uid', 'receiver_firebase_uid']);
            $table->index('firebase_message_id');
            $table->index('sent_at');
            $table->index('is_read');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};