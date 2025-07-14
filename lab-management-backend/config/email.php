<?php
// Email configuration
return [
    'from_address' => getenv('MAIL_FROM_ADDRESS') ?: 'noreply@essentialslots.com',
    'from_name' => getenv('MAIL_FROM_NAME') ?: 'Essential Slots',
    
    // SMTP configuration (if needed)
    'smtp_host' => getenv('SMTP_HOST') ?: 'smtp.gmail.com',
    'smtp_port' => getenv('SMTP_PORT') ?: 25,
    'smtp_username' => getenv('SMTP_USERNAME') ?: 'tomalex161@gmail.com',
    'smtp_password' => getenv('SMTP_PASSWORD') ?: 'ldsg zbsy pqkb enpf ',
    'smtp_secure' => getenv('SMTP_SECURE') ?: 'ssl', // tls or ssl
    'debug' => true, // Enable debugging
];
?>
