<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $day = $_POST['day'] ?? null;
    $time = $_POST['time'] ?? null;
    $room_name = $_POST['room_name'] ?? null;
    $admin_username = $_POST['admin_username'] ?? null;

    if (!$day || !$time || !$room_name || !$admin_username) {
        echo json_encode(['error' => 'Missing required fields']);
        exit;
    }

    // Verify the user is an admin
    $stmt = $conn->prepare("SELECT role FROM users WHERE username = ?");
    $stmt->bind_param("s", $admin_username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if (!$user || $user['role'] !== 'admin') {
        echo json_encode(['error' => 'Unauthorized: Admin access required']);
        exit;
    }

    // Check if booking exists
    $stmt = $conn->prepare("SELECT username FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sis", $day, $time, $room_name);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode(['error' => 'No booking found for this slot']);
        exit;
    }

    // Remove the booking
    $stmt = $conn->prepare("DELETE FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sis", $day, $time, $room_name);
    
    if ($stmt->execute()) {
        echo json_encode(['message' => 'Booking removed successfully']);
    } else {
        echo json_encode(['error' => 'Failed to remove booking']);
    }

    $stmt->close();
}

$conn->close();
?>