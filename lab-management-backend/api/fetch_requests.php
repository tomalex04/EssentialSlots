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

// Fetch pending requests for specific room
$stmt = $conn->prepare("SELECT id, username, day, time, description FROM requests WHERE room_name = ? ORDER BY day, time, id");
$stmt->bind_param("s", $room_name);
$stmt->execute();
$requests_result = $stmt->get_result();

$requests = [];
$slot_counts = [];

while ($row = $requests_result->fetch_assoc()) {
    $requests[] = $row;
    
    // Count requests per slot
    $slot_key = $row['day'] . '-' . $row['time'];
    if (!isset($slot_counts[$slot_key])) {
        $slot_counts[$slot_key] = 1;
    } else {
        $slot_counts[$slot_key]++;
    }
}

// Add count of competing requests to each request
foreach ($requests as $key => $request) {
    $slot_key = $request['day'] . '-' . $request['time'];
    $requests[$key]['competing_requests'] = $slot_counts[$slot_key] - 1; // Exclude self
}

echo json_encode([
    'requests' => $requests
]);

$stmt->close();
$conn->close();
?>
