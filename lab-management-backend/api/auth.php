<?php
require_once '../config/cors.php';  // Add CORS support
require_once '../config/database.php';

header('Content-Type: application/json');

// Enable error reporting for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';

error_log("Login attempt - Username: $username");

if (empty($username) || empty($password)) {
    echo json_encode(['error' => 'Username and password are required']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT id, username, password, role FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        error_log("Login failed - User not found: $username");
        echo json_encode(['error' => 'Invalid username or password']);
        exit;
    }

    $user = $result->fetch_assoc();
    
    if (!password_verify($password, $user['password'])) {
        error_log("Login failed - Invalid password for user: $username");
        echo json_encode(['error' => 'Invalid username or password']);
        exit;
    }

    // Generate session token
    $session_token = bin2hex(random_bytes(32));
    
    // Store session token in database
    $stmt = $conn->prepare("UPDATE users SET session_token = ? WHERE username = ?");
    $stmt->bind_param("ss", $session_token, $username);
    $stmt->execute();

    error_log("Login successful - User: $username, Role: {$user['role']}");
    
    echo json_encode([
        'message' => 'Login successful',
        'username' => $username,
        'role' => $user['role'],
        'session_token' => $session_token
    ]);

} catch (Exception $e) {
    error_log("Login error: " . $e->getMessage());
    echo json_encode(['error' => 'Login failed due to server error']);
}

$conn->close();
?>
