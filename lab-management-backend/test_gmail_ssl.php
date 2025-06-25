<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

echo "Starting Gmail SMTP test with SSL...\n\n";

try {
    $mail = new PHPMailer(true);
    
    echo "Setting up PHPMailer with SSL...\n";
    
    //Server settings
    $mail->SMTPDebug = SMTP::DEBUG_CONNECTION; // Even more verbose debug output
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = 'tomalex161@gmail.com';
    $mail->Password   = 'mkzh xpon puxt pnuc';
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS; // Use SSL instead of TLS
    $mail->Port       = 465; // SSL port

    // Set timeout
    $mail->Timeout = 30; // Timeout in seconds
    
    echo "\nTesting SMTP connection...\n";
    
    //Recipients
    $mail->setFrom('tomalex161@gmail.com', 'Essential Slots');
    $mail->addAddress('tomalex161@gmail.com');

    //Content
    $mail->isHTML(true);
    $mail->Subject = 'SMTP Test Email (SSL)';
    $mail->Body    = 'This is a test email using SSL connection.';

    echo "\nAttempting to send test email...\n";
    $mail->send();
    echo "Test email sent successfully!\n";

} catch (Exception $e) {
    echo "\nError details:\n";
    echo "Message: {$e->getMessage()}\n";
    if (isset($mail)) {
        echo "Mailer Error: {$mail->ErrorInfo}\n";
        echo "Debug Output: \n" . $mail->Debugoutput . "\n";
    }
    
    // Test SSL connection
    echo "\nTesting SSL connection to smtp.gmail.com:465...\n";
    $ctx = stream_context_create([
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false,
        ]
    ]);
    $fp = @stream_socket_client(
        'ssl://smtp.gmail.com:465',
        $errno,
        $errstr,
        30,
        STREAM_CLIENT_CONNECT,
        $ctx
    );
    if (!$fp) {
        echo "Failed to connect: $errstr ($errno)\n";
    } else {
        echo "Basic SSL connection successful\n";
        fclose($fp);
    }
    
    // Additional system info
    echo "\nSystem Information:\n";
    echo "PHP version: " . phpversion() . "\n";
    echo "OpenSSL version: " . OPENSSL_VERSION_TEXT . "\n";
    if (function_exists('curl_version')) {
        $curl = curl_version();
        echo "cURL version: " . $curl['version'] . "\n";
        echo "SSL version: " . $curl['ssl_version'] . "\n";
    }
}
