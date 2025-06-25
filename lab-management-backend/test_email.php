<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Load email configuration
$email_config = require('config/email.php');

// Test email
$to = "test@example.com"; // Replace with your test email
$subject = "Test Email from Essential Slots";
$message = "This is a test email to verify the email configuration.";
$headers = "From: {$email_config['from_name']} <{$email_config['from_address']}>\r\n";
$headers .= "Reply-To: {$email_config['from_address']}\r\n";
$headers .= "MIME-Version: 1.0\r\n";
$headers .= "Content-Type: text/plain; charset=UTF-8\r\n";

if (mail($to, $subject, $message, $headers)) {
    echo "Test email sent successfully!\n";
    echo "From: {$email_config['from_address']}\n";
    echo "Configuration used:\n";
    print_r($email_config);
} else {
    echo "Failed to send test email.\n";
    echo "Check your mail server logs for details.\n";
}
?>
