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
        echo json_encode([
            'success' => false,
            'error' => 'Missing required fields'
        ]);
        exit;
    }

    // Start transaction
    $conn->begin_transaction();

    try {
        // Check if the request exists and belongs to the user
        $stmt = $conn->prepare("SELECT id FROM requests WHERE username = ? AND day = ? AND time = ? AND room_name = ?");
        $stmt->bind_param("ssss", $username, $day, $time, $room_name);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            $conn->rollback();
            echo json_encode([
                'success' => false,
                'error' => 'Request not found or not authorized to cancel'
            ]);
            exit;
        }

        // Delete the request
        $stmt = $conn->prepare("DELETE FROM requests WHERE username = ? AND day = ? AND time = ? AND room_name = ?");
        $stmt->bind_param("ssss", $username, $day, $time, $room_name);
        
        if ($stmt->execute()) {
            $conn->commit();
            echo json_encode([
                'success' => true,
                'message' => 'Request cancelled successfully'
            ]);
        } else {
            $conn->rollback();
            echo json_encode([
                'success' => false,
                'error' => 'Failed to cancel request'
            ]);
        }
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode([
            'success' => false,
            'error' => 'An error occurred: ' . $e->getMessage()
        ]);
    }
}

$conn->close();
?>
