<?php
header('Content-Type: application/json');
require_once '../config/database.php';
require_once '../utils/validation.php';

// Enable error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Get POST data
$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';
$email = $_POST['email'] ?? '';
$phone = $_POST['phone'] ?? '';

// Validate username
$usernameValidation = validateUsername($username);
if (!$usernameValidation['valid']) {
    echo json_encode(['error' => $usernameValidation['message']]);
    exit;
}

// Validate password
$passwordValidation = validatePassword($password);
if (!$passwordValidation['valid']) {
    echo json_encode(['error' => $passwordValidation['message']]);
    exit;
}

// Validate email
if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(['error' => 'Invalid email address.']);
    exit;
}

// Validate phone
if (empty($phone)) {
    echo json_encode(['error' => 'Phone number is required.']);
    exit;
}

try {
    // Check if username already exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        echo json_encode(['error' => 'Username already exists.']);
        exit;
    }

    // Check if email already exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        echo json_encode(['error' => 'Email already registered.']);
        exit;
    }

    // Hash password
    $hashed_password = password_hash($password, PASSWORD_DEFAULT);

    // Insert new user
    $stmt = $conn->prepare("INSERT INTO users (username, password, email, phone, role) VALUES (?, ?, ?, ?, 'user')");
    $stmt->bind_param("ssss", $username, $hashed_password, $email, $phone);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Registration successful']);
    } else {
        echo json_encode(['error' => 'Registration failed: ' . $stmt->error]);
    }

} catch (Exception $e) {
    error_log("Registration error: " . $e->getMessage());
    echo json_encode(['error' => 'Registration failed due to server error.']);
}

$conn->close();
?>
