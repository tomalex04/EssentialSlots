<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
include('../config/database.php');
require_once '../config/otp_cleanup.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Clean up expired OTPs first
    cleanupExpiredOTPs($conn);
    $email = $_POST['email'] ?? null;
    $otp = $_POST['otp'] ?? null;

    if (!$email || !$otp) {
        echo json_encode(['success' => false, 'error' => 'Email and OTP are required']);
        exit;
    }

    // Check OTP validity (exists and not expired)
    $stmt = $conn->prepare("SELECT * FROM otp_verifications WHERE email = ? AND otp = ? AND created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
    $stmt->bind_param("ss", $email, $otp);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        // OTP is valid
        // Delete the used OTP
        $delete_stmt = $conn->prepare("DELETE FROM otp_verifications WHERE email = ?");
        $delete_stmt->bind_param("s", $email);
        $delete_stmt->execute();
        
        echo json_encode(['success' => true, 'message' => 'OTP verified successfully']);
    } else {
        echo json_encode(['success' => false, 'error' => 'Invalid or expired OTP']);
    }
    
    $stmt->close();
}

$conn->close();
?>
