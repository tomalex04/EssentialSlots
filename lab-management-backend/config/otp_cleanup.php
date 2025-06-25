<?php
function cleanupExpiredOTPs($conn) {
    try {
        // Delete OTPs older than 15 minutes
        $stmt = $conn->prepare("DELETE FROM otp_verifications WHERE created_at < DATE_SUB(NOW(), INTERVAL 15 MINUTE)");
        $result = $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        
        if ($affected > 0) {
            error_log("Cleaned up $affected expired OTPs");
        }
        return true;
    } catch (Exception $e) {
        error_log("Error cleaning up OTPs: " . $e->getMessage());
        return false;
    }
}
?>
