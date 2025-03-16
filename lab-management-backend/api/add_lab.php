<?php
header('Content-Type: application/json');
include('../config/database.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $lab_name = $_POST['lab_name'];
    $created_by = $_POST['username'];

    // Create folder path
    $base_directory = '/home/tom/Desktop/lab_files/';
    $folder_path = $base_directory . $lab_name;

    // Ensure the base directory exists
    if (!is_dir($base_directory)) {
        if (!mkdir($base_directory, 0777, true)) {
            echo json_encode(['error' => 'Failed to create base directory: ' . error_get_last()['message']]);
            exit;
        }
    }

    // Ensure the lab-specific directory exists
    if (!is_dir($folder_path)) {
        if (!mkdir($folder_path, 0777, true)) {
            echo json_encode(['error' => 'Failed to create lab directory: ' . error_get_last()['message']]);
            exit;
        }
    }

    // Insert into labs table
    $stmt = $conn->prepare("INSERT INTO labs (name, created_by, folder_path) VALUES (?, ?, ?)");
    if (!$stmt) {
        echo json_encode(['error' => 'Prepare failed: ' . $conn->error]);
        exit;
    }
    $stmt->bind_param("sss", $lab_name, $created_by, $folder_path);
    if ($stmt->execute()) {
        // Verify the insertion
        $insert_id = $stmt->insert_id;
        $stmt->close();

        // Check if the lab was inserted
        $check_stmt = $conn->prepare("SELECT * FROM labs WHERE id = ?");
        $check_stmt->bind_param("i", $insert_id);
        $check_stmt->execute();
        $result = $check_stmt->get_result();
        if ($result->num_rows > 0) {
            echo json_encode(['message' => 'Lab added successfully']);
        } else {
            echo json_encode(['error' => 'Lab insertion verification failed']);
        }
        $check_stmt->close();
    } else {
        echo json_encode(['error' => 'Execute failed: ' . $stmt->error]);
    }
}
?>