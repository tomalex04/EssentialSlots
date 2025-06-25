<?php
// Enable error reporting for debugging
error_log("CORS: Handling request from origin: " . ($_SERVER['HTTP_ORIGIN'] ?? 'none'));
error_log("CORS: Request method: " . $_SERVER['REQUEST_METHOD']);

// For development, accept requests from any origin
if (isset($_SERVER['HTTP_ORIGIN'])) {
    header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
    error_log("CORS: Setting specific origin: {$_SERVER['HTTP_ORIGIN']}");
} else {
    header("Access-Control-Allow-Origin: *");
    error_log("CORS: Setting wildcard origin");
}

// Essential CORS headers
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400'); // Cache preflight for 24 hours
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');

// Handle preflight OPTIONS requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    // Allow all common HTTP methods
    header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
    
    // Allow all requested headers plus common ones
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'])) {
        header("Access-Control-Allow-Headers: {$_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}, X-Requested-With, Content-Type, Accept, Origin, Authorization");
    } else {
        header("Access-Control-Allow-Headers: X-Requested-With, Content-Type, Accept, Origin, Authorization");
    }
    
    // Preflight complete, no need to process further
    exit(0);
}

// Set response headers for non-OPTIONS requests
header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');
?>
