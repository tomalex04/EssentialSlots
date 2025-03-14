<?php
$servername = "localhost";
$username = "root"; // Change this to your database username
$password = "phpmyadmin"; // Change this to your database password
$dbname = "lab_management"; // Change this to your database name

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
