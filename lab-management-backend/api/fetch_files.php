<?php
header('Content-Type: application/json');
include('../config/database.php');

$lab_name = $_GET['lab_name'] ?? null;

if (!$lab_name) {
    echo json_encode(['error' => 'Lab name is required']);
    exit;
}

$query = "SELECT folder_path FROM labs WHERE name = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $lab_name);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$folder_path = $row['folder_path'];

$files = array();
if ($handle = opendir($folder_path)) {
    while (false !== ($entry = readdir($handle))) {
        if ($entry != "." && $entry != "..") {
            $files[] = $entry;
        }
    }
    closedir($handle);
}

echo json_encode($files);
?>