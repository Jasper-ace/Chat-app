<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\Tradie;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class TradieAuthController extends Controller
{
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:tradies',
            'phone' => 'nullable|string|max:20',
            'password' => 'required|string|min:8|confirmed',
            'business_name' => 'nullable|string|max:255',
            'service_category_id' => 'nullable|exists:service_categories,id',
            'license_number' => 'nullable|string|max:100',
            'years_experience' => 'nullable|integer|min:0|max:50',
            'hourly_rate' => 'nullable|numeric|min:0|max:999.99',
            'address' => 'nullable|string|max:500',
            'city' => 'nullable|string|max:100',
            'region' => 'nullable|string|max:100',
            'postal_code' => 'nullable|string|max:10',
            'service_radius' => 'nullable|integer|min:1|max:200',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'The given data was invalid.',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        try {
            // Split name into first_name and last_name
            $nameParts = explode(' ', trim($request->name), 2);
            $firstName = $nameParts[0];
            $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

            $tradie = Tradie::create([
                'first_name' => $firstName,
                'last_name' => $lastName,
                'email' => $request->email,
                'phone' => $request->phone,
                'password' => Hash::make($request->password),
                'business_name' => $request->business_name,
                'service_category_id' => $request->service_category_id,
                'license_number' => $request->license_number,
                'years_experience' => $request->years_experience,
                'hourly_rate' => $request->hourly_rate,
                'address' => $request->address,
                'city' => $request->city,
                'region' => $request->region,
                'postal_code' => $request->postal_code,
                'service_radius' => $request->service_radius ?? 50,
                'availability_status' => 'available',
                'status' => 'active',
            ]);

            $token = $tradie->createToken('tradie-token')->plainTextToken;

            return response()->json([
                'success' => true,
                'data' => [
                    'user' => $this->transformUserData($tradie),
                    'token' => $token,
                ]
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'REGISTRATION_ERROR',
                    'message' => 'Registration failed. Please try again.',
                ]
            ], 500);
        }
    }

    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'The given data was invalid.',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $tradie = Tradie::where('email', $request->email)->first();

        if (!$tradie || !Hash::check($request->password, $tradie->password)) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'INVALID_CREDENTIALS',
                    'message' => 'The provided credentials are incorrect.',
                ]
            ], 401);
        }

        if ($tradie->status !== 'active') {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'ACCOUNT_INACTIVE',
                    'message' => 'Your account is not active. Please contact support.',
                ]
            ], 403);
        }

        // Revoke existing tokens
        $tradie->tokens()->delete();

        $token = $tradie->createToken('tradie-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'data' => [
                'user' => $this->transformUserData($tradie),
                'token' => $token,
            ]
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Successfully logged out'
        ]);
    }

    public function me(Request $request)
    {
        $tradie = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'user' => $this->transformUserData($tradie)
            ]
        ]);
    }

    /**
     * Get all tradies for chat functionality
     */
    public function getAllTradies()
    {
        try {
            $tradies = Tradie::where('status', 'active')->get();
            
            $transformedTradies = $tradies->map(function ($tradie) {
                return $this->transformUserData($tradie);
            });

            return response()->json([
                'success' => true,
                'data' => $transformedTradies
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'FETCH_ERROR',
                    'message' => 'Failed to fetch tradies.',
                ]
            ], 500);
        }
    }

    /**
     * Transform user data to include name field for Flutter app compatibility
     */
    private function transformUserData($tradie)
    {
        // Load service category relationship if not already loaded
        if (!$tradie->relationLoaded('serviceCategory')) {
            $tradie->load('serviceCategory');
        }
        
        $userData = $tradie->toArray();
        
        // Add the 'name' field that Flutter expects
        $userData['name'] = trim($tradie->first_name . ' ' . $tradie->last_name);
        
        // Add user_type for consistency
        $userData['user_type'] = 'tradie';
        
        // Always use service category name as business_name if service_category_id exists
        if ($tradie->serviceCategory) {
            $userData['business_name'] = $tradie->serviceCategory->name;
        }
        
        return $userData;
    }
}
