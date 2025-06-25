<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

// Define base path
define('BASE_PATH', dirname(__DIR__));

require_once BASE_PATH . '/config/otp_cleanup.php';
// Load .env file directly
$env = parse_ini_file(BASE_PATH . '/.env');
if ($env === false) {
    die(json_encode(['success' => false, 'error' => 'Failed to load configuration']));
}

require BASE_PATH . '/vendor/autoload.php';
include(BASE_PATH . '/config/database.php');

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Clean up expired OTPs before sending a new one
    cleanupExpiredOTPs($conn);
    $email = $_POST['email'] ?? null;

    if (!$email) {
        echo json_encode(['success' => false, 'error' => 'Email is required']);
        exit;
    }

    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(['success' => false, 'error' => 'Invalid email format']);
        exit;
    }

    // Generate 6-digit OTP
    $otp = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    
    try {
        // Store OTP in database with timestamp
        $stmt = $conn->prepare("REPLACE INTO otp_verifications (email, otp, created_at) VALUES (?, ?, NOW())");
        if (!$stmt) {
            throw new Exception("Database prepare failed: " . $conn->error);
        }
        
        $stmt->bind_param("ss", $email, $otp);
        if (!$stmt->execute()) {
            throw new Exception("Failed to store OTP: " . $stmt->error);
        }

        // Create a new PHPMailer instance
        $mail = new PHPMailer(true);

        // Enable debug output
        $mail->SMTPDebug = SMTP::DEBUG_SERVER;
        $mail->Debugoutput = function($str, $level) {
            error_log("PHPMailer Debug: $str");
        };

        // Server settings
        $mail->isSMTP();
        $mail->Host = $env['SMTP_HOST'];
        $mail->SMTPAuth = true;
        $mail->Username = $env['SMTP_USERNAME'];
        $mail->Password = $env['SMTP_PASSWORD'];
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = 465;
        $mail->Timeout = 60;

        // Recipients
        $mail->setFrom($env['MAIL_FROM_ADDRESS'], $env['MAIL_FROM_NAME']);
        $mail->addAddress($email);
        $mail->addReplyTo($env['MAIL_FROM_ADDRESS'], $env['MAIL_FROM_NAME']);

        // Content
        $mail->isHTML(true);
        $mail->Subject = 'Your OTP for Lab Management System Registration';
        $mail->Body = "Your OTP is: <strong>{$otp}</strong><br><br>This OTP will expire in 5 minutes.";
        $mail->AltBody = "Your OTP is: {$otp}\n\nThis OTP will expire in 5 minutes.";

        $mail->send();
        echo json_encode(['success' => true, 'message' => 'OTP sent successfully']);
        
    } catch (Exception $e) {
        error_log("OTP Send Error: " . $e->getMessage());
        
        // If any error occurs, clean up the OTP from database
        if (isset($stmt) && $stmt->affected_rows > 0) {
            $delete_stmt = $conn->prepare("DELETE FROM otp_verifications WHERE email = ?");
            $delete_stmt->bind_param("s", $email);
            $delete_stmt->execute();
        }
        
        $error_message = $e->getMessage();
        // For security, don't expose SMTP credentials in production
        $safe_error = str_replace($env['SMTP_PASSWORD'], '****', $error_message);
        echo json_encode(['success' => false, 'error' => 'Failed to send OTP: ' . $safe_error]);
    } finally {
        if (isset($stmt)) {
            $stmt->close();
        }
        if (isset($delete_stmt)) {
            $delete_stmt->close();
        }
    }
}

$conn->close();
?>
