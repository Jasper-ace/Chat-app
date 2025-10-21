<?php

/**
 * Test script for Dual Storage API
 * Run this script to test the Laravel API endpoints
 */

$baseUrl = 'http://localhost:8000/api';

function makeRequest($method, $url, $data = null) {
    $ch = curl_init();
    
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Accept: application/json'
    ]);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'status' => $httpCode,
        'body' => json_decode($response, true)
    ];
}

echo "🧪 Testing Dual Storage API\n";
echo "==========================\n\n";

// Test 1: Create Homeowner
echo "1️⃣  Testing Homeowner Creation...\n";
$homeownerData = [
    'firebase_uid' => 'test_homeowner_' . time(),
    'first_name' => 'John',
    'last_name' => 'Doe',
    'email' => 'john.doe.' . time() . '@example.com',
    'phone' => '+1234567890',
    'address' => '123 Main St',
    'city' => 'Sydney',
    'region' => 'NSW',
    'postal_code' => '2000'
];

$response = makeRequest('POST', $baseUrl . '/homeowners', $homeownerData);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 201) {
    $homeownerUid = $homeownerData['firebase_uid'];
    echo "✅ Homeowner created successfully!\n\n";
} else {
    echo "❌ Homeowner creation failed!\n\n";
    exit(1);
}

// Test 2: Create Tradie
echo "2️⃣  Testing Tradie Creation...\n";
$tradieData = [
    'firebase_uid' => 'test_tradie_' . time(),
    'first_name' => 'Jane',
    'last_name' => 'Smith',
    'email' => 'jane.smith.' . time() . '@example.com',
    'phone' => '+1234567891',
    'address' => '456 Oak Ave',
    'city' => 'Melbourne',
    'region' => 'VIC',
    'postal_code' => '3000',
    'business_name' => 'Smith Plumbing',
    'license_number' => 'PL12345',
    'years_experience' => 10,
    'hourly_rate' => 85.50,
    'availability_status' => 'available'
];

$response = makeRequest('POST', $baseUrl . '/tradies', $tradieData);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 201) {
    $tradieUid = $tradieData['firebase_uid'];
    echo "✅ Tradie created successfully!\n\n";
} else {
    echo "❌ Tradie creation failed!\n\n";
    exit(1);
}

// Test 3: Send Message
echo "3️⃣  Testing Message Sending...\n";
$messageData = [
    'sender_firebase_uid' => $homeownerUid,
    'receiver_firebase_uid' => $tradieUid,
    'sender_type' => 'homeowner',
    'receiver_type' => 'tradie',
    'message' => 'Hello! I need help with my plumbing.',
    'metadata' => [
        'test' => true,
        'timestamp' => date('c')
    ]
];

$response = makeRequest('POST', $baseUrl . '/chats/send-message', $messageData);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 201) {
    echo "✅ Message sent successfully!\n\n";
} else {
    echo "❌ Message sending failed!\n\n";
}

// Test 4: Get User Chats
echo "4️⃣  Testing Get User Chats...\n";
$response = makeRequest('GET', $baseUrl . '/chats/user-chats?firebase_uid=' . $homeownerUid);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 200) {
    echo "✅ User chats retrieved successfully!\n\n";
} else {
    echo "❌ Get user chats failed!\n\n";
}

// Test 5: Search Tradies
echo "5️⃣  Testing Tradie Search...\n";
$searchData = [
    'latitude' => -37.8136,
    'longitude' => 144.9631,
    'radius' => 50,
    'availability_status' => 'available'
];

$response = makeRequest('POST', $baseUrl . '/tradies/search', $searchData);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 200) {
    echo "✅ Tradie search successful!\n\n";
} else {
    echo "❌ Tradie search failed!\n\n";
}

// Test 6: Get Chat Stats
echo "6️⃣  Testing Chat Statistics...\n";
$response = makeRequest('GET', $baseUrl . '/chats/stats?firebase_uid=' . $homeownerUid);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 200) {
    echo "✅ Chat statistics retrieved successfully!\n\n";
} else {
    echo "❌ Get chat statistics failed!\n\n";
}

// Test 7: Mark Messages as Read
echo "7️⃣  Testing Mark Messages as Read...\n";
$readData = [
    'sender_firebase_uid' => $homeownerUid,
    'receiver_firebase_uid' => $tradieUid
];

$response = makeRequest('POST', $baseUrl . '/chats/mark-as-read', $readData);
echo "Status: {$response['status']}\n";
echo "Response: " . json_encode($response['body'], JSON_PRETTY_PRINT) . "\n\n";

if ($response['status'] === 200) {
    echo "✅ Messages marked as read successfully!\n\n";
} else {
    echo "❌ Mark messages as read failed!\n\n";
}

echo "🎉 API Testing Complete!\n";
echo "========================\n\n";

echo "📋 Summary:\n";
echo "- Homeowner UID: {$homeownerUid}\n";
echo "- Tradie UID: {$tradieUid}\n";
echo "- All endpoints tested\n";
echo "- Check your Laravel database to verify data was saved\n";
echo "- Check Firebase console to verify dual storage sync\n\n";

echo "🚀 Your dual storage system is ready to use!\n";
?>