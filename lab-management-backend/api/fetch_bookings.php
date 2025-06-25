<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/cors.php';  // Add CORS support
include('../config/database.php');

// Log the request method and data
error_log("Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("GET data: " . print_r($_GET, true));
error_log("POST data: " . print_r($_POST, true));

// Check for room_name in both GET and POST
$room_name = $_GET['room_name'] ?? $_POST['room_name'] ?? null;

// If it's a POST request, also check the form data
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    error_log("Raw POST input: " . $input);
    if ($input) {
        $data = json_decode($input, true);
        if ($data && isset($data['room_name'])) {
            $room_name = $data['room_name'];
        }
    }
}

error_log("Room name received: " . ($room_name ?? 'null'));

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
