<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? null;
    $day = $_POST['day'] ?? null;
    $time = $_POST['time'] ?? null;
    $room_name = $_POST['room_name'] ?? null;

    if (!$username || !$day || !$time || !$room_name) {
        echo json_encode(['error' => 'Missing required fields']);
        exit;
    }

    // Check if slot is deactivated
    $stmt = $conn->prepare("SELECT * FROM deactivations WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sss", $day, $time, $room_name);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        echo json_encode(['error' => 'Slot is deactivated']);
        exit;
    }

    // Check existing booking
    $stmt = $conn->prepare("SELECT username FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sss", $day, $time, $room_name);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $booking = $result->fetch_assoc();
        // If booked by same user, unbook it
        if ($booking['username'] === $username) {
            $stmt = $conn->prepare("DELETE FROM bookings WHERE username = ? AND day = ? AND time = ? AND room_name = ?");
            $stmt->bind_param("ssss", $username, $day, $time, $room_name);
            if ($stmt->execute()) {
                echo json_encode(['message' => 'Booking removed']);
            } else {
                echo json_encode(['error' => 'Failed to unbook']);
            }
        } else {
            echo json_encode(['error' => 'Slot booked by another user']);
        }
    } else {
        // Book new slot
        $stmt = $conn->prepare("INSERT INTO bookings (username, day, time, room_name) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("ssss", $username, $day, $time, $room_name);
        if ($stmt->execute()) {
            echo json_encode(['message' => 'Slot booked']);
        } else {
            echo json_encode(['error' => 'Booking failed']);
        }
    }
    $stmt->close();
}
$conn->close();
?>
