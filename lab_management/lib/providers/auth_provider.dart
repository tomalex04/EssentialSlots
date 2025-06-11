import 'package:flutter/material.dart';
import 'package:lab_management/services/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const String serverIP = 'localhost';
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? loggedInUser;
  String? userRole;
  String? _sessionToken;
  final Map<String, String?> bookings = {};
  final Map<String, String?> requests = {}; // New map to track slot requests
  final Map<String, String?> descriptions = {}; // Map to store descriptions for slots
  List<List<dynamic>> pendingRequests = []; // List to store pending requests for admin
  List<String> availableLabs = [];
  String? selectedLab;
  late DioClient _dioClient;

  AuthProvider() {
    print('AuthProvider initialized');
    _initDio();
  }

  Future<void> _initDio() async {
    _dioClient = DioClient();
    await _dioClient.init();
    
    // Check for existing session token
    await _loadStoredSession();
    
    // After initializing Dio, fetch the labs
    await fetchLabs();
    print('Labs fetched: $availableLabs');
    if (availableLabs.isNotEmpty) {
      selectedLab = availableLabs[0];
      print('Selected lab: $selectedLab');
      fetchBookings();
    }
  }

  // Load stored session token and verify it
  Future<void> _loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('session_token');
    
    if (storedToken != null) {
      // Verify the token with the server
      try {
        final response = await _dioClient.dio.post(
          'api/verify_session.php',
          data: FormData.fromMap({'session_token': storedToken}),
        );
        
        if (response.statusCode == 200 && response.data['username'] != null) {
          _sessionToken = storedToken;
          loggedInUser = response.data['username'];
          userRole = response.data['role'];
          print('Session restored for user: $loggedInUser');
          notifyListeners();
        } else {
          // Invalid token, remove it
          await prefs.remove('session_token');
        }
      } catch (e) {
        print('Error verifying session token: $e');
        await prefs.remove('session_token');
      }
    }
  }

  // Store session token
  Future<void> _storeSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
    _sessionToken = token;
  }

  // Clear session token
  Future<void> _clearSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    _sessionToken = null;
  }

  Future<void> fetchBookings() async {
    if (selectedLab == null) {
      print('No lab selected');
      return;
    }

    print('Fetching bookings for: $selectedLab');
    try {
      final response = await _dioClient.dio.get(
        'api/fetch_bookings.php',
        queryParameters: {'room_name': selectedLab},
      );
      
      print('Bookings API response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        bookings.clear();
        requests.clear(); // Clear requests map
        descriptions.clear(); // Clear descriptions map

        data['bookings'].forEach((booking) {
          String key = '${booking['day']}-${booking['time']}';
          print('Processing booking: $key = ${booking['username']}');
          bookings[key] = booking['username'];
          if (booking['description'] != null) {
            descriptions[key] = booking['description'];
          }
        });

        data['deactivations'].forEach((deactivation) {
          String key = '${deactivation['day']}-${deactivation['time']}';
          print('Processing deactivation: $key');
          bookings[key] = 'Deactivated by Admin';
        });

        // Also fetch requests for the same lab
        await fetchRequests();

        print('Final bookings map: $bookings');
        print('Final requests map: $requests');
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
  }

  // New method to fetch pending requests
  Future<void> fetchRequests() async {
    if (selectedLab == null) return;

    try {
      final response = await _dioClient.dio.get(
        'api/fetch_requests.php',
        queryParameters: {'room_name': selectedLab},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // For admin view - full details of requests
        pendingRequests = List<List<dynamic>>.from(
          data['requests'].map((request) => [
            request['id'],
            request['username'],
            request['day'],
            request['time'],
            request['description'] ?? '',
            request['competing_requests'] ?? 0
          ])
        );

        // For calendar view - mark slots with pending requests
        data['requests'].forEach((request) {
          String key = '${request['day']}-${request['time']}';
          requests[key] = request['username'];
          if (request['description'] != null) {
            descriptions[key] = request['description'];
          }
        });

        notifyListeners();
      }
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  Future<void> fetchLabs() async {
    print('Fetching labs...');
    try {
      final response = await _dioClient.dio.get('api/fetch_labs.php');
      print('Labs API response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        availableLabs = List<String>.from(data['labs']);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching labs: $e');
    }
  }

  Future<String?> login() async {
    String? validationError = validateInputs();
    if (validationError != null) return validationError;

    try {
      final response = await _dioClient.dio.post(
        'api/auth.php',
        data: FormData.fromMap({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      final responseData = response.data;

      if (responseData['message'] == 'Login successful') {
        loggedInUser = usernameController.text;
        userRole = await getUserRole(usernameController.text);
        
        // Store session token if provided
        if (responseData['session_token'] != null) {
          await _storeSessionToken(responseData['session_token']);
        }
        
        notifyListeners();
        return null;
      } else {
        return responseData['error'] ?? 'Login failed. Please try again.';
      }
    } catch (e) {
      print('Error during login: $e');
      return 'Connection error. Please try again.';
    }
  }

  Future<String?> getUserRole(String username) async {
    try {
      final response = await _dioClient.dio.post(
        'api/get_user_role.php',
        data: FormData.fromMap({
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['role'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  Future<String?> register() async {
    String? validationError = validateInputs();
    if (validationError != null) return validationError;

    if (passwordController.text != confirmPasswordController.text) {
      return 'Passwords do not match.';
    }

    try {
      final response = await _dioClient.dio.post(
        'api/register.php',
        data: FormData.fromMap({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      final responseData = response.data;

      if (responseData['message'] == 'Registration successful') {
        return null;
      } else {
        return responseData['error'] ?? 'Registration failed. Please try again.';
      }
    } catch (e) {
      print('Error during registration: $e');
      return 'Connection error. Please try again.';
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



  Future<bool> activateSlot(String day, String time) async {
    try {
      final response = await _dioClient.dio.post(
        'api/activate.php',
        data: FormData.fromMap({
          'username': loggedInUser,
          'day': day,
          'time': time,
          'room_name': selectedLab,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

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
      } else {
        print('Error: Received status code ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error activating slot: $e');
      return false;
    }
  }

  Future<bool> removeBooking(String day, String time) async {
    try {
      final response = await _dioClient.dio.post(
        'api/remove_booking.php',
        data: FormData.fromMap({
          'day': day,
          'time': time,
          'room_name': selectedLab,
          'admin_username': loggedInUser,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['message'] == 'Booking removed successfully') {
          // Remove from local bookings map
          bookings.remove('$day-$time');
          notifyListeners();
          return true;
        } else {
          print('Failed to remove booking: ${responseData['error']}');
          return false;
        }
      } else {
        print('Error: Received status code ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error removing booking: $e');
      return false;
    }
  }

  Future<bool> addLab(String labName) async {
    try {
      final response = await _dioClient.dio.post(
        'api/add_lab.php',
        data: FormData.fromMap({
          'lab_name': labName,
          'username': loggedInUser,
        }),
      );
      
      if (response.statusCode == 200) {
        await fetchLabs();
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding lab: $e');
      return false;
    }
  }

  Future<bool> requestSlot(String day, String time, {String description = ''}) async {
    print('Requesting slot: day=$day, time=$time, username=$loggedInUser, description=$description');
    try {
      final response = await _dioClient.dio.post(
        'api/request_slot.php',
        data: FormData.fromMap({
          'username': loggedInUser,
          'day': day,
          'time': time,
          'room_name': selectedLab,
          'description': description,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.data}');

      final responseData = response.data;

      if (responseData['message'] == 'Request submitted') {
        // Mark this slot as requested by the current user
        requests['$day-$time'] = loggedInUser;
        if (description.isNotEmpty) {
          descriptions['$day-$time'] = description;
        }
        notifyListeners();
        return true;
      } else if (responseData['message'] == 'Request cancelled') {
        // Remove this request
        requests.remove('$day-$time');
        descriptions.remove('$day-$time');
        notifyListeners();
        return true;
      } else {
        if (responseData['error'] == 'Slot already has a pending request from another user') {
          // Another user already requested this slot
          print('Request failed: ${responseData['error']}');
          // Refresh data to show the latest state
          await fetchBookings();
        } else {
          print('Request failed: ${responseData['error']}');
        }
        return false;
      }
    } catch (e) {
      print('Error requesting slot: $e');
      return false;
    }
  }

  // New method to handle request approvals/rejections
  Future<bool> handleRequest(int requestId, String action) async {
    print('Handling request: id=$requestId, action=$action');
    try {
      final response = await _dioClient.dio.post(
        'api/handle_request.php',
        data: FormData.fromMap({
          'request_id': requestId.toString(),
          'action': action,
          'admin_username': loggedInUser,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.data}');

      final responseData = response.data;

      if (responseData['message'] != null && !responseData['message'].toString().contains('failed')) {
        // Refresh data to show the latest state
        await fetchBookings();
        return true;
      } else {
        print('Request handling failed: ${responseData['error']}');
        return false;
      }
    } catch (e) {
      print('Error handling request: $e');
      return false;
    }
  }

  // Method to logout
  Future<void> logout() async {
    // Clear session token on server if we have one
    if (_sessionToken != null) {
      try {
        await _dioClient.dio.post(
          'api/logout.php',
          data: FormData.fromMap({'session_token': _sessionToken}),
        );
      } catch (e) {
        print('Error during logout: $e');
      }
    }
    
    // Clear local session token
    await _clearSessionToken();
    
    // Clear session cookies
    _dioClient.clearCookies();
    
    // Reset user state
    loggedInUser = null;
    userRole = null;
    
    notifyListeners();
  }
}
