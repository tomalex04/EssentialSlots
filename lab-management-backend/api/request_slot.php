<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require '../vendor/autoload.php';
include('../config/database.php');

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

function sendAdminNotification($slots, $username, $description, $room_name) {
    try {
        error_log("Starting admin notification process for user: $username");
        
        // Get admin emails with a prepared statement for safety
        $stmt = $GLOBALS['conn']->prepare("SELECT DISTINCT email FROM users WHERE role = 'admin' AND email IS NOT NULL AND email != ''");
        if (!$stmt) {
            error_log("Failed to prepare admin email query: " . $GLOBALS['conn']->error);
            return false;
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        
        if (!$result) {
            error_log("Query failed to get admin emails");
            return false;
        }
        
        if ($result->num_rows === 0) {
            error_log("No admin emails found in database");
            return false;
        }
        
        error_log("Found " . $result->num_rows . " admin email(s)");
        
        $admin_emails = [];
        while ($row = $result->fetch_assoc()) {
            $admin_emails[] = $row['email'];
        }
        
        $stmt->close();
        
        if (empty($admin_emails)) {
            error_log("No valid admin emails found");
            return false;
        }
        
        // Load email configuration
        $env = parse_ini_file(__DIR__ . '/../.env');
        if ($env === false) {
            error_log("Failed to load .env file");
            return false;
        }
        
        error_log("Loaded email configuration from .env file");
        
        $mail = new PHPMailer(true);
        $mail->SMTPDebug = SMTP::DEBUG_SERVER;
        $mail->Debugoutput = function($str, $level) {
            error_log("PHPMailer Debug: $str");
        };
        
        $mail->isSMTP();
        $mail->Host = $env['SMTP_HOST'];
        $mail->SMTPAuth = true;
        $mail->Username = $env['SMTP_USERNAME'];
        $mail->Password = $env['SMTP_PASSWORD'];
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = 465;
        $mail->Timeout = 30;
        
        $mail->setFrom($env['MAIL_FROM_ADDRESS'], $env['MAIL_FROM_NAME']);
        foreach ($admin_emails as $admin_email) {
            $mail->addAddress($admin_email);
        }
        
        $mail->isHTML(true);
        $mail->Subject = "New Slot Request(s) from $username for $room_name";
        
        $body = "<h2>New Slot Request Details</h2>";
        $body .= "<p><strong>Lab/Room:</strong> " . htmlspecialchars($room_name) . "</p>";
        $body .= "<p><strong>Requester:</strong> " . htmlspecialchars($username) . "</p>";
        if (!empty($description)) {
            $body .= "<p><strong>Description:</strong> " . htmlspecialchars($description) . "</p>";
        }
        $body .= "<h3>Requested Slots:</h3><ul>";
        
        foreach ($slots as $slot) {
            $date = $slot['date'];
            $time = $slot['time'];
            $body .= "<li>Date: $date, Time: $time</li>";
        }
        
        $body .= "</ul>";
        $mail->Body = $body;
        
        error_log("Attempting to send email notification");
        if ($mail->send()) {
            error_log("Email notification sent successfully");
            return true;
        } else {
            error_log("Failed to send email: " . $mail->ErrorInfo);
            return false;
        }
    } catch (Exception $e) {
        $error = $e->getMessage();
        // Remove sensitive info before logging
        $error = preg_replace('/(?<=password=)[^&\s]+/i', '***', $error);
        error_log("Failed to send admin notification: " . $error);
        return false;
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Parse input data
    $input = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        // Try form data if JSON parsing failed
        $username = $_POST['username'] ?? null;
        $slots = $_POST['slots'] ?? null;
        $description = $_POST['description'] ?? '';
        $room_name = $_POST['room_name'] ?? null;
    } else {
        $username = $input['username'] ?? null;
        $slots = $input['slots'] ?? null;
        $description = $input['description'] ?? '';
        $room_name = $input['room_name'] ?? null;
    }
    
    error_log("Request data: " . print_r([
        'username' => $username,
        'slots' => $slots,
        'description' => $description,
        'room_name' => $room_name
    ], true));

    if (!$username || !$slots || !$room_name) {
        echo json_encode([
            'success' => false, 
            'error' => 'Missing required fields', 
            'details' => [
                'username' => $username ? 'present' : 'missing',
                'slots' => $slots ? 'present' : 'missing',
                'room_name' => $room_name ? 'present' : 'missing'
            ]
        ]);
        exit;
    }
    
    // Validate description
    if (!empty($description) && strlen(trim($description)) < 2) {
        echo json_encode(['success' => false, 'error' => 'Description must contain at least 2 characters']);
        exit;
    }
    
    // If slots is a string (from form data), try to decode it
    if (is_string($slots)) {
        $slots = json_decode($slots, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            echo json_encode(['success' => false, 'error' => 'Invalid slots format']);
            exit;
        }
    }

    // Start transaction
    $conn->begin_transaction();
    
    try {
        $successful_slots = [];
        $failed_slots = [];
        
        foreach ($slots as $slot) {
            $day = $slot['date'];
            $time = $slot['time'];
            
            error_log("Processing slot: date=$day, time=$time, room=$room_name");
            
            // Check if slot is deactivated
            $stmt = $conn->prepare("SELECT * FROM deactivations WHERE day = ? AND time = ? AND room_name = ?");
            $stmt->bind_param("sss", $day, $time, $room_name);
            $stmt->execute();
            $deactivated = $stmt->get_result()->num_rows > 0;
            $stmt->close();
            
            if ($deactivated) {
                $failed_slots[] = ['date' => $day, 'time' => $time, 'reason' => 'Slot is deactivated'];
                error_log("Slot deactivated: $day-$time");
                continue;
            }

            // Check existing booking
            $stmt = $conn->prepare("SELECT username FROM bookings WHERE day = ? AND time = ? AND room_name = ?");
            $stmt->bind_param("sss", $day, $time, $room_name);
            $stmt->execute();
            $isBooked = $stmt->get_result()->num_rows > 0;
            $stmt->close();
            
            if ($isBooked) {
                $failed_slots[] = ['date' => $day, 'time' => $time, 'reason' => 'Slot is already booked'];
                error_log("Slot already booked: $day-$time");
                continue;
            }

            // Check existing requests
            $stmt = $conn->prepare("SELECT username FROM requests WHERE day = ? AND time = ? AND room_name = ?");
            $stmt->bind_param("sss", $day, $time, $room_name);
            $stmt->execute();
            $result = $stmt->get_result();
            $hasExistingRequest = false;
            
            if ($result->num_rows > 0) {
                $request = $result->fetch_assoc();
                if ($request['username'] !== $username) {
                    $failed_slots[] = ['date' => $day, 'time' => $time, 'reason' => 'Slot already has a pending request from ' . $request['username']];
                    error_log("Slot has pending request from {$request['username']}: $day-$time");
                    $stmt->close();
                    continue;
                }
                $hasExistingRequest = true;
            }
            $stmt->close();

            // Insert or update request
            $stmt = $conn->prepare("INSERT INTO requests (username, day, time, room_name, description) 
                                  VALUES (?, ?, ?, ?, ?) 
                                  ON DUPLICATE KEY UPDATE description = ?, username = ?");
            $stmt->bind_param("sssssss", $username, $day, $time, $room_name, $description, $description, $username);
            
            if ($stmt->execute()) {
                $successful_slots[] = ['date' => $day, 'time' => $time];
            } else {
                $failed_slots[] = ['date' => $day, 'time' => $time, 'reason' => 'Database error'];
            }
        }
        
        // If no slots were successful, rollback
        if (empty($successful_slots)) {
            $conn->rollback();
            echo json_encode([
                'success' => false,
                'error' => 'No slots could be requested',
                'failed_slots' => $failed_slots
            ]);
            exit;
        }
        
        // Commit transaction
        $conn->commit();
        
        // Send immediate success response
        echo json_encode([
            'success' => true,
            'message' => empty($failed_slots) ? 'All slots requested successfully' : 'Some slots were requested successfully',
            'slots' => $successful_slots,
            'failed_slots' => $failed_slots
        ]);
        
        // Flush output to ensure response is sent
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } else {
            ob_end_flush();
            flush();
        }
        
        // Send admin notification in the background
        if (!empty($successful_slots)) {
            ignore_user_abort(true);
            set_time_limit(30);
            
            error_log("Attempting to send admin notification for successful slots from $username");
            try {
                $notificationSent = sendAdminNotification($successful_slots, $username, $description, $room_name);
                error_log("Admin notification status: " . ($notificationSent ? "sent" : "failed"));
            } catch (Exception $e) {
                error_log("Exception while sending admin notification: " . $e->getMessage());
            }
        }
        
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode([
            'success' => false,
            'error' => 'An error occurred while processing your request: ' . $e->getMessage()
        ]);
    }
}

$conn->close();
?>
