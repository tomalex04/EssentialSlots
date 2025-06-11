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
    $description = $_POST['description'] ?? '';

    if (!$username || !$day || !$time || !$room_name) {
        echo json_encode(['error' => 'Missing required fields']);
        exit;
    }
    
    // Validate description - must have at least 2 non-whitespace characters
    if (strlen(trim($description)) < 2) {
        echo json_encode(['error' => 'Description must contain at least 2 characters']);
        exit;
    }

    // Check if slot is deactivated
    $stmt = $conn->prepare("SELECT * FROM deactivations WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sis", $day, $time, $room_name);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        echo json_encode(['error' => 'Slot is deactivated']);
        exit;
    }

    // Check existing booking
    $stmt = $conn->prepare("SELECT username FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sis", $day, $time, $room_name);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(['error' => 'Slot already booked']);
        exit;
    }

    // Check if any user already has a request for this slot
    $stmt = $conn->prepare("SELECT username FROM requests WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sis", $day, $time, $room_name);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $request = $result->fetch_assoc();
        // If requested by the same user, cancel the request
        if ($request['username'] === $username) {
            $stmt = $conn->prepare("DELETE FROM requests WHERE username = ? AND day = ? AND time = ? AND room_name = ?");
            $stmt->bind_param("ssis", $username, $day, $time, $room_name);
            if ($stmt->execute()) {
                echo json_encode(['message' => 'Request cancelled']);
            } else {
                echo json_encode(['error' => 'Failed to cancel request']);
            }
        } else {
            echo json_encode(['error' => 'Slot already has a pending request from another user']);
        }
    } else {
        // Create new request
        $stmt = $conn->prepare("INSERT INTO requests (username, day, time, room_name, description) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("ssiss", $username, $day, $time, $room_name, $description);
        if ($stmt->execute()) {
            echo json_encode(['message' => 'Request submitted']);
        } else {
            echo json_encode(['error' => 'Request submission failed']);
        }
    }
    $stmt->close();
}
$conn->close();
?>
