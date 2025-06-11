-- Add session_token column to users table for persistent login
ALTER TABLE `users` ADD COLUMN `session_token` varchar(255) DEFAULT NULL AFTER `role`;