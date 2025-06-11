<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? null;
    $currentPassword = $_POST['current_password'] ?? null;
    $newPassword = $_POST['new_password'] ?? null;

    if (!$username || !$currentPassword || !$newPassword) {
        echo json_encode(['error' => 'Missing required fields']);
        exit;
    }

    // Validate new password length
    if (strlen($newPassword) < 8) {
        echo json_encode(['error' => 'New password must be at least 8 characters long']);
        exit;
    }

    // Verify current password
    $stmt = $conn->prepare("SELECT password FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if (!$user || !password_verify($currentPassword, $user['password'])) {
        echo json_encode(['error' => 'Current password is incorrect']);
        exit;
    }

    // Hash new password and clear session token to force re-login
    $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
    
    $updateStmt = $conn->prepare("UPDATE users SET password = ?, session_token = NULL WHERE username = ?");
    $updateStmt->bind_param("ss", $hashedPassword, $username);
    
    if ($updateStmt->execute()) {
        echo json_encode(['message' => 'Password updated successfully. Please log in again.']);
    } else {
        echo json_encode(['error' => 'Failed to update password']);
    }

    $updateStmt->close();
    $stmt->close();
}

$conn->close();
?>
