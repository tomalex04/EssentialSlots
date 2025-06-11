<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $sessionToken = $_POST['session_token'] ?? null;

    if (!$sessionToken) {
        echo json_encode(['error' => 'No session token provided']);
        exit;
    }

    // Clear the session token
    $stmt = $conn->prepare("UPDATE users SET session_token = NULL WHERE session_token = ?");
    $stmt->bind_param("s", $sessionToken);
    $stmt->execute();

    if ($stmt->affected_rows > 0) {
        echo json_encode(['message' => 'Logout successful']);
    } else {
        echo json_encode(['error' => 'Invalid session token']);
    }

    $stmt->close();
}

$conn->close();
?>
