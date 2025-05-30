<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

include('../config/database.php');

$room_name = $_GET['room_name'] ?? null;

if (!$room_name) {
    echo json_encode(['error' => 'Room name is required']);
    exit;
}

// Fetch bookings for specific room
$stmt = $conn->prepare("SELECT username, day, time, description FROM bookings WHERE room_name = ?");
$stmt->bind_param("s", $room_name);
$stmt->execute();
$bookings_result = $stmt->get_result();

$bookings = [];
while ($row = $bookings_result->fetch_assoc()) {
    $bookings[] = $row;
}

// Fetch deactivations for specific room
$stmt = $conn->prepare("SELECT deactivated_by, day, time FROM deactivations WHERE room_name = ?");
$stmt->bind_param("s", $room_name);
$stmt->execute();
$deactivations_result = $stmt->get_result();

$deactivations = [];
while ($row = $deactivations_result->fetch_assoc()) {
    $deactivations[] = $row;
}

echo json_encode([
    'bookings' => $bookings,
    'deactivations' => $deactivations
]);

$stmt->close();
$conn->close();
?>
