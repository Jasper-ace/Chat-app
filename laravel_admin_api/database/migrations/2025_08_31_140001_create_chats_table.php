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
        Schema::create('chats', function (Blueprint $table) {
            $table->id();
            $table->string('firebase_chat_id')->unique(); // Firebase chat ID
            $table->string('participant_1_uid'); // Firebase UID of first participant
            $table->string('participant_2_uid'); // Firebase UID of second participant
            $table->enum('participant_1_type', ['homeowner', 'tradie']);
            $table->enum('participant_2_type', ['homeowner', 'tradie']);
            $table->unsignedBigInteger('participant_1_id')->nullable(); // Laravel ID
            $table->unsignedBigInteger('participant_2_id')->nullable(); // Laravel ID
            $table->text('last_message')->nullable();
            $table->string('last_sender_uid')->nullable();
            $table->timestamp('last_message_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            // Indexes
            $table->index(['participant_1_uid', 'participant_2_uid']);
            $table->index('firebase_chat_id');
            $table->index('last_message_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chats');
    }
};