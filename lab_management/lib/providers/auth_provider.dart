import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  static const String serverIP = 'localhost';
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? loggedInUser;
  String? userRole;
  final Map<String, String?> bookings = {};
  List<String> availableLabs = [];
  String? selectedLab;

  AuthProvider() {
    print('AuthProvider initialized');
    fetchLabs().then((_) {
      print('Labs fetched: $availableLabs');
      if (availableLabs.isNotEmpty) {
        selectedLab = availableLabs[0];
        print('Selected lab: $selectedLab');
        fetchBookings();
      }
    });
  }

  Future<void> fetchBookings() async {
    if (selectedLab == null) {
      print('No lab selected');
      return;
    }

    print('Fetching bookings for: $selectedLab');
    final response = await http.get(
      Uri.parse(
          'http://$serverIP/lab-management-backend/api/fetch_bookings.php?room_name=$selectedLab'),
    );
    print('Bookings API response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      bookings.clear();

      data['bookings'].forEach((booking) {
        String key = '${booking['day']}-${booking['time']}';
        print('Processing booking: $key = ${booking['username']}');
        bookings[key] = booking['username'];
      });

      data['deactivations'].forEach((deactivation) {
        String key = '${deactivation['day']}-${deactivation['time']}';
        print('Processing deactivation: $key');
        bookings[key] = 'Deactivated by Admin';
      });

      print('Final bookings map: $bookings');
      notifyListeners();
    }
  }

  Future<void> fetchLabs() async {
    print('Fetching labs...');
    final response = await http.get(
      Uri.parse('http://$serverIP/lab-management-backend/api/fetch_labs.php'),
    );
    print('Labs API response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      availableLabs = List<String>.from(data['labs']);
      notifyListeners();
    }
  }

  Future<String?> login() async {
    String? validationError = validateInputs();
    if (validationError != null) return validationError;

    final response = await http.post(
      Uri.parse('http://$serverIP/lab-management-backend/api/auth.php'),
      body: {
        'username': usernameController.text,
        'password': passwordController.text,
      },
    );

    final responseData = json.decode(response.body);

    if (responseData['message'] == 'Login successful') {
      loggedInUser = usernameController.text;
      userRole = await getUserRole(usernameController.text);
      notifyListeners();
      return null;
    } else {
      return responseData['error'] ?? 'Login failed. Please try again.';
    }
  }

  Future<String?> getUserRole(String username) async {
    final response = await http.post(
      Uri.parse(
          'http://$serverIP/lab-management-backend/api/get_user_role.php'),
      body: {
        'username': username,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['role'];
    } else {
      return null;
    }
  }

  Future<String?> register() async {
    String? validationError = validateInputs();
    if (validationError != null) return validationError;

    if (passwordController.text != confirmPasswordController.text) {
      return 'Passwords do not match.';
    }

    final response = await http.post(
      Uri.parse('http://$serverIP/lab-management-backend/api/register.php'),
      body: {
        'username': usernameController.text,
        'password': passwordController.text,
      },
    );

    final responseData = json.decode(response.body);

    if (responseData['message'] == 'Registration successful') {
      return null;
    } else {
      return responseData['error'] ?? 'Registration failed. Please try again.';
    }
  }

  String? validateInputs() {
    if (usernameController.text.length < 5) {
      return 'Username must be at least 5 characters long.';
    }
    if (passwordController.text.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;
  }

  Future<bool> bookSlot(String day, String time) async {
    print('Booking slot: day=$day, time=$time, username=$loggedInUser');
    final response = await http.post(
      Uri.parse('http://$serverIP/lab-management-backend/api/book.php'),
      body: {
        'username': loggedInUser,
        'day': day,
        'time': time,
        'room_name': selectedLab,
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    final responseData = json.decode(response.body);

    if (responseData['message'] == 'Slot booked') {
      // This block is for when the booking is added
      bookings['$day-$time'] = loggedInUser;
      notifyListeners();
      return true;
    } else if (responseData['message'] == 'Booking removed') {
      // This block is for when the booking is removed
      bookings.remove('$day-$time');
      notifyListeners();
      return true;
    } else {
      print('Booking failed: ${responseData['error']}');
      return false;
    }
  }

  Future<bool> activateSlot(String day, String time) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIP/lab-management-backend/api/activate.php'),
        body: {
          'username': loggedInUser,
          'day': day,
          'time': time,
          'room_name': selectedLab,
        },
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      if (response.statusCode == 200) {
        try {
          // Attempt to parse the JSON
          final responseData = json.decode(response.body);

          if (responseData['message'] == 'Slot deactivated successfully') {
            bookings['$day-$time'] = 'Deactivated by admin';
            notifyListeners();
            return true;
          } else if (responseData['message'] == 'Slot activated successfully') {
            bookings.remove('$day-$time');
            notifyListeners();
            return true;
          } else {
            print('Unexpected message: ${responseData['message']}');
            return false;
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          return false;
        }
      } else {
        print('Error: Received status code ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  Future<bool> addLab(String labName) async {
    final response = await http.post(
      Uri.parse('http://$serverIP/lab-management-backend/api/add_lab.php'),
      body: {
        'lab_name': labName,
        'username': loggedInUser,
      },
    );
    if (response.statusCode == 200) {
      await fetchLabs();
      return true;
    }
    return false;
  }
}
