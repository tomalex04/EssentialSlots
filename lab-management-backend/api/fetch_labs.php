<?php
require_once '../config/cors.php';  // Add CORS support
include('../config/database.php');

$result = $conn->query("SELECT name FROM labs ORDER BY name");
$labs = [];

while ($row = $result->fetch_assoc()) {
    $labs[] = $row['name'];
}

echo json_encode(['labs' => $labs]);
?>
