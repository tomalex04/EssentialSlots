# EssentialSlots: Lab Management System

EssentialSlots is a comprehensive Lab Management System featuring a **Flutter** mobile/web application and a **PHP/MySQL** backend. It allows users to book laboratory slots and administrators to manage lab availability, add new labs, and monitor bookings.

---

## 🚀 Features

### **For Users**

* **Authentication**: Secure registration and login system with password hashing.
* **Lab Selection**: View and select from multiple available labs.
* **Slot Booking**: Interactive grid interface to book or remove personal bookings for the next 10 days.
* **Real-time Availability**: Color-coded slots (Green for available, Red for your bookings, Yellow for others, Grey for deactivated).

### **For Administrators**

* **Role-based Access**: Specialized dashboard restricted to admin users.
* **Lab Management**: Add new laboratory rooms to the system.
* **Slot Deactivation**: Block specific time slots or entire days from being booked.
* **Date Range View**: Select specific "From" and "To" dates to manage slot availability at scale.

---

## 🛠️ Tech Stack

* **Frontend**: Flutter (Dart)
* **State Management**: Provider
* **Backend**: PHP (MySQLi)
* **Database**: MySQL

---

## 📋 Database Schema

The system uses a relational database named `lab_management` with the following key tables:

* `users`: Stores credentials and roles (`admin` or `user`).
* `labs`: Contains list of available laboratory rooms.
* `bookings`: Records user-specific slot reservations.
* `deactivations`: Tracks slots blocked by administrators.

---

## ⚙️ Setup Instructions

### **Backend Setup**

1. Navigate to `lab-management-backend/config/database.php`.
2. Update the `$username`, `$password`, and `$dbname` variables to match your local MySQL configuration.
3. Import the provided `lab_management_dump.sql` file into your MySQL server to initialize the tables and sample data.

### **Frontend Setup**

1. Open `lab_management/lib/providers/auth_provider.dart`.
2. Update the `serverIP` constant to point to your backend hosting (e.g., `localhost/lab_management`).
3. Run the following commands in the `lab_management` directory:
```bash
flutter pub get
flutter run

```



---

## 📖 API Documentation

The backend provides several JSON endpoints in the `api/` directory:

* `auth.php`: Handles user login.
* `register.php`: Handles new user registration.
* `book.php`: Manages slot booking and unbooking.
* `fetch_labs.php`: Returns the list of available labs.
* `activate.php`: Toggles slot deactivation for admins.
