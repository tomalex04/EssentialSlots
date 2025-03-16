<?php
header('Content-Type: application/json');
include('../config/database.php');

$lab_name = $_GET['lab_name'] ?? null;
$file_name = $_GET['file_name'] ?? null;

if (!$lab_name || !$file_name) {
    echo json_encode(['error' => 'Lab name and file name are required']);
    exit;
}

$query = "SELECT folder_path FROM labs WHERE name = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $lab_name);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$folder_path = $row['folder_path'];

$file_path = $folder_path . '/' . $file_name;
if (file_exists($file_path)) {
    unlink($file_path);

    // Check if the folder is empty
    if (count(glob($folder_path . '/*')) === 0) {
        rmdir($folder_path);
    }

    echo json_encode(['message' => 'File deleted successfully']);
} else {
    echo json_encode(['error' => 'File not found']);
}
?>