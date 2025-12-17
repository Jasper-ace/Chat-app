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
        Schema::create('job_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_offer_id')->constrained('homeowner_job_offers')->onDelete('cascade');
            $table->foreignId('tradie_id')->constrained('tradies')->onDelete('cascade');
            $table->enum('status', ['pending', 'accepted', 'rejected', 'withdrawn'])->default('pending');
            $table->text('cover_letter')->nullable();
            $table->decimal('proposed_price', 10, 2)->nullable();
            $table->timestamps();
            
            // Ensure a tradie can only apply once per job
            $table->unique(['job_offer_id', 'tradie_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('job_applications');
    }
};
