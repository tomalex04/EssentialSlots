<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

// Function to read .env file
function loadEnv($path) {
    if (!file_exists($path)) {
        throw new Exception('.env file not found');
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '#') === 0) continue;
        list($name, $value) = explode('=', $line, 2);
        $name = trim($name);
        $value = trim($value);
        if (!empty($name)) {
            // Remove quotes if present
            $value = trim($value, '"');
            $value = trim($value, "'");
            putenv(sprintf('%s=%s', $name, $value));
        }
    }
}

try {
    echo "Loading .env file...\n";
    loadEnv(__DIR__ . '/.env');
    
    echo "Environment variables loaded:\n";
    echo "SMTP_HOST: " . getenv('SMTP_HOST') . "\n";
    echo "SMTP_PORT: " . getenv('SMTP_PORT') . "\n";
    echo "SMTP_USERNAME: " . getenv('SMTP_USERNAME') . "\n";
    echo "SMTP_SECURE: " . getenv('SMTP_SECURE') . "\n";
    
    $mail = new PHPMailer(true);
    
    echo "\nSetting up PHPMailer...\n";
    
    $mail->SMTPDebug = SMTP::DEBUG_SERVER;
    $mail->isSMTP();
    $mail->Host = getenv('SMTP_HOST');
    $mail->SMTPAuth = true;
    $mail->Username = getenv('SMTP_USERNAME');
    $mail->Password = getenv('SMTP_PASSWORD');
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
    $mail->Port = 465;
    $mail->Timeout = 60;
    
    $mail->setFrom(getenv('MAIL_FROM_ADDRESS'), getenv('MAIL_FROM_NAME'));
    $mail->addAddress(getenv('SMTP_USERNAME'));
    
    $mail->isHTML(true);
    $mail->Subject = 'Direct Env Test';
    $mail->Body = 'This is a test email reading directly from .env file.';
    
    echo "\nSending email...\n";
    $mail->send();
    echo "Email sent successfully!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    if (isset($mail)) {
        echo "Mailer Error: " . $mail->ErrorInfo . "\n";
    }
}
