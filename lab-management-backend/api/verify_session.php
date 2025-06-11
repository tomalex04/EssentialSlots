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

    $stmt = $conn->prepare("SELECT username, role FROM users WHERE session_token = ?");
    $stmt->bind_param("s", $sessionToken);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if ($user) {
        echo json_encode([
            'message' => 'Session valid',
            'username' => $user['username'],
            'role' => $user['role']
        ]);
    } else {
        echo json_encode(['error' => 'Invalid session token']);
    }

    $stmt->close();
}

$conn->close();
?>