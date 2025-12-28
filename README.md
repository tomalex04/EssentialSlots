# EssentialSlots - Lab Management System

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.5.4-02569B?logo=flutter)](https://flutter.dev)
[![PHP](https://img.shields.io/badge/Backend-PHP-777BB4?logo=php)](https://www.php.net)
[![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1?logo=mysql)](https://www.mysql.com)

**EssentialSlots** is a robust Lab Management System built with **Flutter** for the frontend and **PHP/MySQL** for the backend. It allows educational institutions or organizations to manage computer lab bookings efficiently, offering role-based access for Admins and Users.

---

## 📋 Table of Contents

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Screenshots](#-screenshots)
- [Installation & Setup](#-installation--setup)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Database Schema](#-database-schema)
- [License](#-license)

---

## ✨ Features

### 👤 User Module
* **Authentication**: Secure Login and Registration system.
* **View Availability**: Real-time view of lab slot availability for the next 10 days.
* **Slot Booking**: Users can book available time slots (hours 1-6) for specific dates.
* **Status Indicators**: Visual cues for Available (Green), Booked by Self (Red), Booked by Others (Yellow), and Deactivated (Grey) slots.
* **Multi-Lab Support**: Switch between different labs to view their specific schedules.

### 🛡️ Admin Module
* **Dashboard**: Comprehensive view of all bookings across all labs.
* **Slot Management**: Ability to **Deactivate** specific slots or days (e.g., for maintenance or holidays).
* **Admin Booking**: Admins can book slots on behalf of users or for administrative purposes.
* **Lab Management**: Interface to **Add New Labs** to the system dynamically.
* **Date Range Filtering**: Filter schedules by specific date ranges.

---

## 🛠 Tech Stack

### Frontend (Mobile App)
* **Framework**: [Flutter](https://flutter.dev) (Dart)
* **State Management**: [Provider](https://pub.dev/packages/provider)
* **Networking**: `http` package for API communication.

### Backend (API)
* **Language**: PHP (Native)
* **Database**: MySQL
* **Authentication**: JSON handling with secure password hashing.

---

## 🚀 Installation & Setup

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* A web server with PHP and MySQL support (e.g., [XAMPP](https://www.apachefriends.org/), [MAMP](https://www.mamp.info/), or a live server).

### Backend Setup

1.  **Deploy Files**: Move the contents of the `lab-management-backend` folder to your web server's root directory (e.g., `htdocs` in XAMPP).
2.  **Database Configuration**:
    * Create a new MySQL database named `lab_management`.
    * Import the `lab_management/lab_management_dump.sql` file into your database to set up the tables (`bookings`, `deactivations`, `labs`, `users`).
3.  **Update Credentials**:
    * Open `lab-management-backend/config/database.php`.
    * Update the `$username`, `$password`, and `$dbname` variables to match your database environment.

    ```php
    // config/database.php
    $servername = "localhost";
    $username = "root"; 
    $password = "your_password"; 
    $dbname = "lab_management"; 
    ```

### Frontend Setup

1.  **Clone/Download** the repository.
2.  Navigate to the flutter project directory:
    ```bash
    cd lab_management
    ```
3.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
4.  **Configure API URL**:
    * Locate the file responsible for API calls (likely `lib/providers/auth_provider.dart` or a constant file).
    * Change the base URL to point to your hosted backend IP address (use your machine's IP address if testing on a physical device/emulator, not `localhost`).
5.  **Run the App**:
    ```bash
    flutter run
    ```

---

## 🗄 Database Schema

The system uses four main tables:

1.  **`users`**: Stores user credentials and roles (`admin`, `user`).
2.  **`labs`**: Stores information about different labs available for booking.
3.  **`bookings`**: Records user bookings linked to specific days, times, and labs.
4.  **`deactivations`**: Tracks slots disabled by the admin.

---

## 📄 License

Copyright 2025 EssentialSlots Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
