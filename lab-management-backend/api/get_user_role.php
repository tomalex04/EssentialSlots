<?php
require_once('../config/database.php');
require_once('../config/cors.php');  // Add proper CORS support
header('Content-Type: application/json');

// Enable error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

error_log("get_user_role.php - Starting role fetch");

if (!isset($_POST['session_token'])) {
    error_log("get_user_role.php - No session token provided");
    echo json_encode([
        'status' => 'error',
        'message' => 'No session token provided'
    ]);
    exit;
}

$session_token = $_POST['session_token'];
error_log("get_user_role.php - Fetching role for session: $session_token");

// Get user role from the database
$stmt = $conn->prepare("
    SELECT username, role, id 
    FROM users 
    WHERE session_token = ?
");

if (!$stmt) {
    error_log("get_user_role.php - SQL Error: " . $conn->error);
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error'
    ]);
    exit;
}

$stmt->bind_param("s", $session_token);
$success = $stmt->execute();

if (!$success) {
    error_log("get_user_role.php - Execute failed: " . $stmt->error);
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to execute query'
    ]);
    $stmt->close();
    exit;
}

$result = $stmt->get_result();

if ($result->num_rows === 0) {
    error_log("get_user_role.php - No user found for session token");
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid session token'
    ]);
    $stmt->close();
    exit;
}

$user = $result->fetch_assoc();

// Verify that we have a valid role
if (empty($user['role'])) {
    error_log("get_user_role.php - User found but no role set for user: {$user['username']}");
    echo json_encode([
        'status' => 'error',
        'message' => 'No role assigned to user'
    ]);
    $stmt->close();
    exit;
}

error_log("get_user_role.php - Found user: {$user['username']}, role: {$user['role']}");

echo json_encode([
    'status' => 'success',
    'role' => $user['role'],
    'username' => $user['username']
]);

$stmt->close();
$conn->close();
?>
