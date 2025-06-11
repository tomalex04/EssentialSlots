<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'];
    $password = $_POST['password'];

    $stmt = $conn->prepare("SELECT * FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if ($user && password_verify($password, $user['password'])) {
        // Generate a unique session token
        $sessionToken = bin2hex(random_bytes(32));
        
        // Store the session token in the database
        $updateStmt = $conn->prepare("UPDATE users SET session_token = ? WHERE username = ?");
        $updateStmt->bind_param("ss", $sessionToken, $username);
        $updateStmt->execute();
        $updateStmt->close();
        
        echo json_encode([
            'message' => 'Login successful',
            'session_token' => $sessionToken
        ]);
    } else {
        echo json_encode(['error' => 'Invalid username or password']);
    }

    $stmt->close();
}

$conn->close();
?>
