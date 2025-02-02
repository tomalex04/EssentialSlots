<?php
$password = 'adminadmin'; // Change this to your desired admin password
$hashed_password = password_hash($password, PASSWORD_BCRYPT);
echo $hashed_password;
?>
