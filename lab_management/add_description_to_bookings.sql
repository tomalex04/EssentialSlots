-- Add description column to bookings table
ALTER TABLE `bookings` ADD COLUMN `description` varchar(100) DEFAULT NULL AFTER `room_name`;
