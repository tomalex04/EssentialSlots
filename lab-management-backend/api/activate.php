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

    // Check if already deactivated
    $stmt = $conn->prepare("SELECT * FROM deactivations WHERE day = ? AND time = ? AND room_name = ?");
    $stmt->bind_param("sss", $day, $time, $room_name);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        // Already deactivated - activate it
        $stmt = $conn->prepare("DELETE FROM deactivations WHERE day = ? AND time = ? AND room_name = ?");
        $stmt->bind_param("sss", $day, $time, $room_name);
        $message = "Slot activated successfully";
    } else {
        // Not deactivated - deactivate it
        $stmt = $conn->prepare("INSERT INTO deactivations (deactivated_by, day, time, room_name) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("ssss", $username, $day, $time, $room_name);
        $message = "Slot deactivated successfully";
    }

    if ($stmt->execute()) {
        echo json_encode(['message' => $message]);
    } else {
        echo json_encode(['error' => 'Operation failed']);
    }

    $stmt->close();
}

$conn->close();
?>
