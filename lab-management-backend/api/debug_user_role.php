<?php
require_once('../config/database.php');
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

if (!isset($_POST['session_token'])) {
    echo json_encode(['status' => 'error', 'message' => 'No session token provided']);
    exit;
}

$session_token = $_POST['session_token'];

// Get user details from session
$stmt = $conn->prepare("SELECT users.username, users.role, users.id FROM users 
                       JOIN sessions ON users.id = sessions.user_id 
                       WHERE sessions.session_token = ?");
$stmt->bind_param("s", $session_token);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid session']);
    exit;
}

$row = $result->fetch_assoc();
echo json_encode([
    'status' => 'success',
    'data' => [
        'username' => $row['username'],
        'role' => $row['role'],
        'user_id' => $row['id']
    ]
]);

$stmt->close();
$conn->close();
?>
