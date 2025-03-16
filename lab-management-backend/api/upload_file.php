<?php
header('Content-Type: application/json');
include('../config/database.php');

$lab_name = $_POST['lab_name'] ?? null;
$file = $_FILES['file'] ?? null;

if (!$lab_name || !$file) {
    echo json_encode(['error' => 'Lab name and file are required']);
    exit;
}

// Allowed MIME types
$allowed_mime_types = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
];

// Get the MIME type of the uploaded file
$file_mime_type = mime_content_type($file['tmp_name']);

if (!in_array($file_mime_type, $allowed_mime_types)) {
    echo json_encode(['error' => 'Invalid file type. Only PDF, DOC, DOCX, and TXT files are allowed.']);
    exit;
}

$query = "SELECT folder_path FROM labs WHERE name = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $lab_name);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$folder_path = $row['folder_path'];

// Ensure the base directory exists
$base_directory = '/home/tom/Desktop/lab_files/';
if (!is_dir($base_directory)) {
    mkdir($base_directory, 0777, true);
}

// Ensure the lab-specific directory exists
if (!is_dir($folder_path)) {
    mkdir($folder_path, 0777, true);
}

// Check if there are any existing files in the lab-specific directory
$existing_files = glob($folder_path . '/*');
if (count($existing_files) > 0) {
    echo json_encode(['error' => 'Only one file is allowed at a time.']);
    exit;
}

$target_file = $folder_path . '/' . basename($file['name']);
if (move_uploaded_file($file['tmp_name'], $target_file)) {
    echo json_encode(['message' => 'File uploaded successfully']);
} else {
    echo json_encode(['error' => 'File upload failed']);
}
?>