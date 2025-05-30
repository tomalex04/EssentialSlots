<?php

session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'domain' => '', // or your IP if needed
    'secure' => false,
    'httponly' => true,
    'samesite' => 'Lax'
]);
session_start();

$servername = "localhost";
$username = "root"; // Change this to your database username
$password = "phpmyadmin"; // Change this to your database password
$dbname = "lab_management"; // Change this to your database name

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
