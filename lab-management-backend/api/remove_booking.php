<?php
require_once('../config/database.php');
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

error_log("[remove_booking.php] Request started");
error_log("[remove_booking.php] POST data: " . print_r($_POST, true));

// Enable error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Validate required parameters
if (!isset($_POST['session_token']) || !isset($_POST['day']) || !isset($_POST['time'])) {
    error_log("[remove_booking.php] Missing required parameters");
    echo json_encode(['status' => 'error', 'message' => 'Missing required parameters']);
    exit;
}

$session_token = $_POST['session_token'];
$day = $_POST['day'];
$time = $_POST['time'];

// Get user information from the session token
$stmt = $conn->prepare("SELECT id, role, username FROM users WHERE session_token = ?");

$stmt->bind_param("s", $session_token);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    error_log("[remove_booking.php] Invalid or expired session token");
    echo json_encode(['status' => 'error', 'message' => 'Invalid or expired session']);
    exit;
}

$user = $result->fetch_assoc();
$user_id = $user['id'];
$user_role = $user['role'];
$username = $user['username'];

error_log("[remove_booking.php] User details - ID: $user_id, Username: $username, Role: $user_role");

// Get the booking information
$stmt = $conn->prepare("SELECT id, username FROM bookings WHERE day = ? AND time = ?");
$stmt->bind_param("ss", $day, $time);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    error_log("[remove_booking.php] No booking found for day: $day, time: $time");
    echo json_encode(['status' => 'error', 'message' => 'Booking not found']);
    exit;
}

$booking = $result->fetch_assoc();
error_log("[remove_booking.php] Booking found - ID: {$booking['id']}, Booked by: {$booking['booked_by']} (ID: {$booking['user_id']})");

// Check permissions
$can_remove = false;
$reason = '';

if ($user_role === 'admin') {
    $can_remove = true;
    error_log("[remove_booking.php] Admin access granted for user $username");
} elseif ($username === $booking['username']) {
    $can_remove = true;
    error_log("[remove_booking.php] User owns the booking - access granted");
} else {
    $reason = 'You can only remove your own bookings';
    error_log("[remove_booking.php] Permission denied - User $username attempted to remove booking owned by {$booking['username']}");
}

if (!$can_remove) {
    echo json_encode([
        'status' => 'error',
        'message' => $reason ?: 'Permission denied',
        'debug' => [
            'requesting_user' => [
                'id' => $user_id,
                'username' => $username,
                'role' => $user_role
            ],
            'booking' => [
                'id' => $booking['id'],
                'user_id' => $booking['user_id'],
                'booked_by' => $booking['booked_by']
            ]
        ]
    ]);
    exit;
}

// Proceed with booking removal
$stmt = $conn->prepare("DELETE FROM bookings WHERE day = ? AND time = ? AND username = ?");
$stmt->bind_param("sss", $day, $time, $booking['username']);
$success = $stmt->execute();

error_log("[remove_booking.php] Delete query executed - Success: " . ($success ? 'true' : 'false'));
error_log("[remove_booking.php] Affected rows: " . $stmt->affected_rows);

if ($success && $stmt->affected_rows > 0) {
    error_log("[remove_booking.php] Booking successfully removed");
    echo json_encode([
        'status' => 'success',
        'message' => 'Booking removed successfully',
        'debug' => [
            'booking' => [
                'id' => $booking['id'],
                'day' => $day,
                'time' => $time,
                'removed_by' => $username,
                'removed_by_role' => $user_role
            ],
            'affected_rows' => $stmt->affected_rows
        ]
    ]);
} else {
    $error = $conn->error;
    error_log("[remove_booking.php] Failed to remove booking - MySQL Error: $error");
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to remove booking',
        'debug' => [
            'booking_id' => $booking['id'],
            'day' => $day,
            'time' => $time,
            'mysql_error' => $error,
            'affected_rows' => $stmt->affected_rows
        ]
    ]);
}

$stmt->close();
$conn->close();
?>