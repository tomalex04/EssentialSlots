<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

echo "Starting Gmail SMTP test...\n\n";

try {
    $mail = new PHPMailer(true);
    
    echo "Setting up PHPMailer...\n";
    
    //Server settings
    $mail->SMTPDebug = SMTP::DEBUG_SERVER; // Enable verbose debug output
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = 'tomalex161@gmail.com';
    $mail->Password   = 'mkzh xpon puxt pnuc';
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;

    echo "\nTesting SMTP connection...\n";
    
    // Try to connect without sending
    if ($mail->smtpConnect()) {
        echo "SMTP Connection successful!\n";
        
        //Recipients
        $mail->setFrom('tomalex161@gmail.com', 'Essential Slots');
        $mail->addAddress('tomalex161@gmail.com'); // Send to self for testing

        //Content
        $mail->isHTML(true);
        $mail->Subject = 'SMTP Test Email';
        $mail->Body    = 'This is a test email to verify SMTP settings are working correctly.';

        echo "\nAttempting to send test email...\n";
        $mail->send();
        echo "Test email sent successfully!\n";
    } else {
        throw new Exception("Failed to connect to SMTP server");
    }

} catch (Exception $e) {
    echo "\nError details:\n";
    echo "Message: {$e->getMessage()}\n";
    if (isset($mail)) {
        echo "Mailer Error: {$mail->ErrorInfo}\n";
    }
    
    // Additional connection testing
    echo "\nTesting basic connection to smtp.gmail.com:587...\n";
    $fp = @fsockopen('smtp.gmail.com', 587, $errno, $errstr, 30);
    if (!$fp) {
        echo "Failed to connect: $errstr ($errno)\n";
    } else {
        echo "Basic TCP connection successful\n";
        fclose($fp);
    }
}
