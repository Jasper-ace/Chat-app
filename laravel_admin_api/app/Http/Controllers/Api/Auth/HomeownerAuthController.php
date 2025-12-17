<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\Homeowner;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class HomeownerAuthController extends Controller
{
    /**
     * Register a new homeowner
     *
     * This method handles the creation of a new homeowner user.
     * It validates the input, hashes the password, creates the user, 
     * and returns an API token for authentication.
     */
    public function register(Request $request)
    {
        // Step 1: Validate incoming request data
        $validator = Validator::make($request->all(), [
            'name'        => 'required|string|max:255',   // Required, max 255 chars
            'email'       => 'required|string|email|max:255|unique:homeowners,email', // Must be unique
            'phone'       => 'nullable|string|max:20',   // Optional, max 20 chars
            'password'    => 'required|string|min:8|confirmed', // Must match password_confirmation
            'address'     => 'nullable|string|max:500',
            'city'        => 'nullable|string|max:100',
            'region'      => 'nullable|string|max:100',
            'postal_code' => 'nullable|string|max:10',
        ]);

        // Step 2: Return errors if validation fails
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'error'   => [
                    'code'    => 'VALIDATION_ERROR',
                    'message' => 'The given data was invalid.',
                    'details' => $validator->errors(), // Detailed field errors
                ],
            ], 422); // 422 Unprocessable Entity
        }

        // Step 3: Split name into first_name and last_name
        $nameParts = explode(' ', trim($request->name), 2);
        $firstName = $nameParts[0];
        $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

        // Step 3: Create the homeowner record
        $homeowner = Homeowner::create([
            'first_name'  => $firstName,
            'last_name'   => $lastName,
            'email'       => $request->email,
            'phone'       => $request->phone,
            'password'    => Hash::make($request->password), // Hash password securely
            'address'     => $request->address,
            'city'        => $request->city,
            'region'      => $request->region,
            'postal_code' => $request->postal_code,
            'status'      => 'active', // Default to active; consider 'pending' for email verification
        ]);

        // Step 4: Generate API token using Laravel Sanctum
        $token = $homeowner->createToken('homeowner-token')->plainTextToken;

        // Step 5: Return success response with user data and token in expected format
        return response()->json([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'expires_in' => 3600, // 1 hour
            'user' => $this->transformUserData($homeowner),
        ], 201); // 201 Created
    }

    /**
     * Login homeowner
     *
     * Validates credentials, checks account status, revokes old tokens,
     * and issues a new Sanctum token for API authentication.
     */
    public function login(Request $request)
    {
        // Step 1: Validate login input
        $validator = Validator::make($request->all(), [
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        // Step 2: Return errors if validation fails
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'error'   => [
                    'code'    => 'VALIDATION_ERROR',
                    'message' => 'The given data was invalid.',
                    'details' => $validator->errors(),
                ],
            ], 422);
        }

        // Step 3: Find the homeowner by email
        $homeowner = Homeowner::where('email', $request->email)->first();

        // Step 4: Verify password
        if (!$homeowner || !Hash::check($request->password, $homeowner->password)) {
            return response()->json([
                'success' => false,
                'error'   => [
                    'code'    => 'INVALID_CREDENTIALS',
                    'message' => 'The provided credentials are incorrect.',
                ],
            ], 401); // 401 Unauthorized
        }

        // Step 5: Check account status
        if ($homeowner->status !== 'active') {
            return response()->json([
                'success' => false,
                'error'   => [
                    'code'    => 'ACCOUNT_INACTIVE',
                    'message' => 'Your account is not active. Please contact support.',
                ],
            ], 403); // 403 Forbidden
        }

        // Step 6: Revoke any previous tokens to prevent session hijacking
        $homeowner->tokens()->delete();

        // Step 7: Issue a new API token
        $token = $homeowner->createToken('homeowner-token')->plainTextToken;

        // Step 8: Return success response with token in expected format
        return response()->json([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'expires_in' => 3600, // 1 hour
            'user' => $this->transformUserData($homeowner),
        ]);
    }

    /**
     * Logout homeowner
     *
     * Deletes the current token to revoke API access.
     */
    public function logout(Request $request)
    {
        // Delete the token used for this request only
        $request->user()->currentAccessToken()->delete();

        // Return success message
        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully',
        ]);
    }

    /**
     * Get authenticated homeowner
     *
     * Returns the currently logged-in homeowner info.
     */
    public function me(Request $request)
    {
        $homeowner = $request->user(); // Fetched via Sanctum authentication

        if (!$homeowner) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'UNAUTHENTICATED',
                    'message' => 'User not authenticated',
                ]
            ], 401);
        }

        return response()->json([
            'success' => true,
            'data' => $this->transformUserData($homeowner),
        ]);
    }

    /**
     * Show homeowner profile page (for admin panel)
     *
     * Only authorized admins should access this route.
     */
    public function show(Homeowner $homeowner)
    {
        // Pass the homeowner data to the Blade view
        return view('filament.admin.pages.homeowner-profile-page', compact('homeowner'));
    }

    /**
     * Get all homeowners for chat functionality
     */
    public function getAllHomeowners()
    {
        try {
            $homeowners = Homeowner::where('status', 'active')->get();
            
            $transformedHomeowners = $homeowners->map(function ($homeowner) {
                return $this->transformUserData($homeowner);
            });

            return response()->json([
                'success' => true,
                'data' => $transformedHomeowners
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => 'FETCH_ERROR',
                    'message' => 'Failed to fetch homeowners.',
                ]
            ], 500);
        }
    }

    /**
     * Transform user data to include name field for Flutter app compatibility
     */
    private function transformUserData($homeowner)
    {
        $userData = $homeowner->toArray();
        
        // Add the 'name' field that Flutter expects
        $userData['name'] = trim($homeowner->first_name . ' ' . $homeowner->last_name);
        
        // Add user_type for consistency
        $userData['user_type'] = 'homeowner';
        
        return $userData;
    }
}
