<?php

use App\Http\Controllers\Api\Auth\HomeownerAuthController;
use App\Http\Controllers\Api\Auth\TradieAuthController;
use App\Http\Controllers\Api\Auth\UserAuthController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\JobOfferController;
use App\Http\Controllers\Api\ChatController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// Homeowner Authentication Routes
Route::prefix('homeowner')->group(function () {
    Route::post('register', [HomeownerAuthController::class, 'register']);
    Route::post('login', [HomeownerAuthController::class, 'login']);
    
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('logout', [HomeownerAuthController::class, 'logout']);
        Route::get('me', [HomeownerAuthController::class, 'me']);
    });
});

Route::prefix('user')->group(function () {
    Route::post('login', [UserAuthController::class, 'login']);
    
});

// Tradie Authentication Routes
Route::prefix('tradie')->group(function () {
    Route::post('register', [TradieAuthController::class, 'register']);
    Route::post('login', [TradieAuthController::class, 'login']);
    
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('logout', [TradieAuthController::class, 'logout']);
        Route::get('me', [TradieAuthController::class, 'me']);
    });
});

// Protected routes for authenticated users
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    
    // Get all tradies for chat
    Route::get('/tradies', [TradieAuthController::class, 'getAllTradies']);
    
    // Get all homeowners for chat
    Route::get('/homeowners', [HomeownerAuthController::class, 'getAllHomeowners']);
});

// Chat Routes
Route::prefix('chats')->middleware('auth:sanctum')->group(function () {
    Route::post('/send-message', [ChatController::class, 'sendMessage']);
    Route::post('/create-room', [ChatController::class, 'createRoom']);
    Route::get('/user-chats', [ChatController::class, 'getUserChats']);
    Route::get('/{chatId}/messages', [ChatController::class, 'getChatMessages']);
    Route::post('/mark-as-read', [ChatController::class, 'markAsRead']);
    Route::get('/stats', [ChatController::class, 'getChatStats']);
    Route::post('/search', [ChatController::class, 'searchMessages']);
    Route::post('/sync-firebase', [ChatController::class, 'syncFirebaseMessages']);
    Route::post('/block-user', [ChatController::class, 'blockUser']);
    Route::post('/unblock-user', [ChatController::class, 'unblockUser']);
});

// Public Job and Service Routes (POSTMAN)
Route::prefix('jobs')->group(function () {
    Route::get('/categories', [ServiceController::class, 'index']);
    Route::get('/categories/{id}', [ServiceController::class, 'indexSpecificCategory']);
    Route::get('/categories/{id}/services', [ServiceController::class, 'indexSpecificCategoryServices']);
    Route::get('/services', [ServiceController::class, 'indexService']);
    Route::get('/services/{id}', [ServiceController::class, 'indexSpecificService']);
});


// Homeowner & Tradie Jobs
Route::prefix('jobs')->middleware('auth:sanctum')->group(function () {
    // Homeowner routes
    Route::get('/job-offers', [JobOfferController::class, 'index']);
    Route::post('/job-offers', [JobOfferController::class, 'store']);
    Route::get('/job-offers/{id}', [JobOfferController::class, 'show']);
    Route::put('/job-offers/{id}', [JobOfferController::class, 'update']);
    Route::delete('/job-offers/{id}', [JobOfferController::class, 'destroy']);
    
    // Tradie routes
    Route::get('/available', [JobOfferController::class, 'getAvailableJobsForTradie']);
    Route::post('/{jobId}/apply', [JobOfferController::class, 'applyForJob']);
    
    // Get applications for a job (homeowner only)
    Route::get('/{jobId}/applications', [JobOfferController::class, 'getJobApplications']);
    
    // Update application status (accept/reject)
    Route::put('/{jobId}/applications/{applicationId}', [JobOfferController::class, 'updateApplicationStatus']);
});