<?php
header('Content-Type: application/json');
require_once('../config/database.php');

$query = "SELECT email FROM users WHERE role = 'admin' AND email IS NOT NULL";
$result = $conn->query($query);

$admin_emails = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        if (!empty($row['email'])) {
            $admin_emails[] = $row['email'];
        }
    }
}

echo json_encode(['success' => true, 'emails' => $admin_emails]);

$conn->close();
?>
