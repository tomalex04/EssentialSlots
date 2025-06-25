<?php
function validateUsername($username) {
    if (empty($username)) {
        return ['valid' => false, 'message' => 'Username is required.'];
    }
    
    if (strlen($username) < 5) {
        return ['valid' => false, 'message' => 'Username must be at least 5 characters long.'];
    }
    
    return ['valid' => true];
}

function validatePassword($password) {
    if (empty($password)) {
        return ['valid' => false, 'message' => 'Password is required.'];
    }
    
    if (strlen($password) < 10) {
        return ['valid' => false, 'message' => 'Password must be at least 10 characters long.'];
    }
    
    if (!preg_match('/[0-9]/', $password)) {
        return ['valid' => false, 'message' => 'Password must contain at least one number.'];
    }
    
    if (!preg_match('/[A-Z]/', $password)) {
        return ['valid' => false, 'message' => 'Password must contain at least one uppercase letter.'];
    }
    
    if (!preg_match('/[a-z]/', $password)) {
        return ['valid' => false, 'message' => 'Password must contain at least one lowercase letter.'];
    }
    
    if (!preg_match('/[!@#\$%^&*(),.?":{}|<>]/', $password)) {
        return ['valid' => false, 'message' => 'Password must contain at least one symbol.'];
    }
    
    return ['valid' => true];
}
?>
