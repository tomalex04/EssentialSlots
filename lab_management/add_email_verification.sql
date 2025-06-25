-- Add OTP verifications table
CREATE TABLE IF NOT EXISTS `otp_verifications` (
  `email` varchar(255) NOT NULL,
  `otp` varchar(6) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Add email and phone columns to users table
ALTER TABLE `users` 
ADD COLUMN `email` varchar(255) UNIQUE,
ADD COLUMN `phone` varchar(20);
