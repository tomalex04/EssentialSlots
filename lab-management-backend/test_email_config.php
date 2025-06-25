<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

// Load email configuration
$email_config = require('config/email.php');

echo "Current Email Configuration:\n";
echo "SMTP Host: " . $email_config['smtp_host'] . "\n";
echo "SMTP Port: " . $email_config['smtp_port'] . "\n";
echo "SMTP Username: " . $email_config['smtp_username'] . "\n";
echo "SMTP Password: " . ($email_config['smtp_password'] ? '[SET]' : '[NOT SET]') . "\n";
echo "SMTP Secure: " . $email_config['smtp_secure'] . "\n";
echo "From Address: " . $email_config['from_address'] . "\n";
echo "From Name: " . $email_config['from_name'] . "\n";

echo "\nTesting SMTP Connection...\n";

try {
    $mail = new PHPMailer(true);
    
    $mail->SMTPDebug = SMTP::DEBUG_SERVER;
    $mail->isSMTP();
    $mail->Host = $email_config['smtp_host'];
    $mail->SMTPAuth = true;
    $mail->Username = $email_config['smtp_username'];
    $mail->Password = $email_config['smtp_password'];
    $mail->SMTPSecure = $email_config['smtp_secure'] === 'tls' ? PHPMailer::ENCRYPTION_STARTTLS : PHPMailer::ENCRYPTION_SMTPS;
    $mail->Port = $email_config['smtp_port'];
    
    // Try to connect to SMTP server without sending email
    if($mail->smtpConnect()) {
        echo "\nSMTP connection successful!\n";
        $mail->smtpClose();
    } else {
        echo "\nSMTP connection failed!\n";
    }
    
} catch (Exception $e) {
    echo "\nError: " . $e->getMessage() . "\n";
}
?>
