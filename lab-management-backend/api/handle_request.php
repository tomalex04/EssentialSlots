<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $request_id = $_POST['request_id'] ?? null;
    $action = $_POST['action'] ?? null; // 'approve' or 'reject'
    $admin_username = $_POST['admin_username'] ?? null;

    if (!$request_id || !$action || !$admin_username) {
        echo json_encode(['error' => 'Missing required fields']);
        exit;
    }

    // Get request details
    $stmt = $conn->prepare("SELECT * FROM requests WHERE id = ?");
    $stmt->bind_param("i", $request_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows == 0) {
        echo json_encode(['error' => 'Request not found']);
        exit;
    }

    $request = $result->fetch_assoc();
    $day = $request['day'];
    $time = $request['time'];
    $username = $request['username'];
    $room_name = $request['room_name'];
    $description = $request['description'];

    // Start transaction
    $conn->begin_transaction();

    try {
        if ($action === 'approve') {
            // Check if the slot has been booked in the meantime
            $check_stmt = $conn->prepare("SELECT * FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
            $check_stmt->bind_param("sis", $day, $time, $room_name);
            $check_stmt->execute();
            $check_result = $check_stmt->get_result();
            
            if ($check_result->num_rows > 0) {
                // Slot is already booked
                $conn->rollback();
                echo json_encode(['error' => 'Slot is already booked']);
                exit;
            }

            // Check for other pending requests for this slot
            $other_requests_stmt = $conn->prepare("SELECT id FROM requests WHERE day = ? AND time = ? AND room_name = ? AND id != ?");
            $other_requests_stmt->bind_param("sisi", $day, $time, $room_name, $request_id);
            $other_requests_stmt->execute();
            $other_requests_result = $other_requests_stmt->get_result();
            $other_request_count = $other_requests_result->num_rows;

            // Add to bookings table with description
            $insert_stmt = $conn->prepare("INSERT INTO bookings (username, day, time, room_name, description) VALUES (?, ?, ?, ?, ?)");
            $insert_stmt->bind_param("ssiss", $username, $day, $time, $room_name, $description);
            $insert_stmt->execute();
            
            // Auto-reject all other requests for the same slot
            if ($other_request_count > 0) {
                $delete_other_stmt = $conn->prepare("DELETE FROM requests WHERE day = ? AND time = ? AND room_name = ? AND id != ?");
                $delete_other_stmt->bind_param("sisi", $day, $time, $room_name, $request_id);
                $delete_other_stmt->execute();
            }
        }
        
        // Delete from requests table regardless of approve/reject
        $delete_stmt = $conn->prepare("DELETE FROM requests WHERE id = ?");
        $delete_stmt->bind_param("i", $request_id);
        $delete_stmt->execute();
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode([
            'message' => ($action === 'approve') 
                ? ($other_request_count > 0 
                    ? "Request approved and $other_request_count other request(s) for this slot were automatically rejected" 
                    : 'Request approved and slot booked')
                : 'Request rejected'
        ]);
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(['error' => 'Transaction failed: ' . $e->getMessage()]);
    }
}
$conn->close();
?>
