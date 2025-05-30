<?php
header('Content-Type: application/json');
include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $lab_name = $_POST['lab_name'];
    $created_by = $_POST['username'];

    $stmt = $conn->prepare("INSERT INTO labs (name, created_by) VALUES (?, ?)");
    $stmt->bind_param("ss", $lab_name, $created_by);

    echo json_encode(['message' => $stmt->execute() ? 'Success' : 'Failed']);
}
?>
