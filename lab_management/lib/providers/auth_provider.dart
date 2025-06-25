import 'package:flutter/material.dart';
import 'package:lab_management/services/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? loggedInUser;
  String? userRole;  // Store user role
  String? _sessionToken;
  final Map<String, String?> bookings = {};
  final Map<String, String?> requests = {}; // New map to track slot requests
  final Map<String, String?> descriptions = {}; // Map to store descriptions for slots
  List<List<dynamic>> pendingRequests = []; // List to store pending requests for admin
  List<String> availableLabs = [];
  String? _selectedLab;
  String? get selectedLab => _selectedLab;
  set selectedLab(String? value) {
    if (_selectedLab != value) {
      _selectedLab = value;
      notifyListeners();
      // Don't call fetchBookings here, let the UI handle it
    }
  }
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
          // Fetch data after session restore
          await fetchLabs();
          if (availableLabs.isNotEmpty) {
            selectedLab = availableLabs[0];
            await fetchBookings();
          }
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
      print('Fetching bookings with lab: $selectedLab');
      final response = await _dioClient.dio.post(
        'api/fetch_bookings.php',
        data: FormData.fromMap({
          'room_name': selectedLab,
        }),
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
      print('Attempting login for: ${usernameController.text}');
      final response = await _dioClient.dio.post(
        'api/auth.php',
        data: FormData.fromMap({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      print('Auth response: ${response.data}');
      
      if (response.statusCode != 200) {
        print('Login failed: Bad status code ${response.statusCode}');
        return 'Login failed. Please try again.';
      }

      final responseData = response.data;
      if (responseData['message'] != 'Login successful') {
        print('Login failed: ${responseData['error'] ?? 'Unknown error'}');
        return responseData['error'] ?? 'Login failed. Please try again.';
      }

      // Login successful
      loggedInUser = usernameController.text;
      
      // Store session token
      if (responseData['session_token'] == null) {
        print('No session token in response');
        return 'Login failed: Server error';
      }
      
      await _storeSessionToken(responseData['session_token']);
      print('Session token stored');
      
      // Get user role
      try {
        final roleSuccess = await _fetchUserRole();
        if (!roleSuccess) {
          print('Failed to get user role');
          await _clearSessionToken();
          return 'Login failed: Could not determine user role';
        }
        
        print('Login successful - User: $loggedInUser, Role: $userRole');
        
        // Fetch labs and bookings after successful login
        await fetchLabs();
        if (availableLabs.isNotEmpty) {
          selectedLab = availableLabs[0];
          await fetchBookings();
        }
        
        notifyListeners();
        return null;
        
      } catch (e) {
        print('Error fetching role: $e');
        await _clearSessionToken();
        return 'Login failed: Could not get user role';
      }
      
    } catch (e) {
      print('Login error: $e');
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            return 'Connection timeout. Please check your internet connection and try again.';
          case DioExceptionType.connectionError:
            return 'Cannot connect to server. Please verify the server is running and accessible.';
          default:
            if (e.response?.statusCode == 404) {
              return 'Server endpoint not found. Please check server configuration.';
            }
            return 'Connection error: ${e.message}';
        }
      }
      return 'Connection error. Please try again.';
    }
  }

  Future<bool> _fetchUserRole() async {
    if (_sessionToken == null) {
      print('Cannot fetch role: No session token');
      return false;
    }

    try {
      print('Fetching user role with token: $_sessionToken');
      final response = await _dioClient.dio.post(
        'api/get_user_role.php',
        data: FormData.fromMap({
          'session_token': _sessionToken,
        }),
      );

      print('Role response status: ${response.statusCode}');
      print('Role response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 'success' && data['role'] != null) {
          userRole = data['role'].toString();
          print('User role set to: $userRole');
          return true;
        } else {
          print('Invalid role response: ${response.data}');
          if (data['message'] != null) {
            print('Role error message: ${data['message']}');
          }
          userRole = null;
        }
      } else {
        print('Failed to get role - Status: ${response.statusCode}');
        userRole = null;
      }
    } catch (e) {
      print('Error in _fetchUserRole: $e');
      userRole = null;
    }
    return false;
  }

  Future<bool> sendOTP(String email) async {
    try {
      final response = await _dioClient.dio.post(
        'api/send_otp.php',
        data: FormData.fromMap({
          'email': email,
        }),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final response = await _dioClient.dio.post(
        'api/verify_otp.php',
        data: FormData.fromMap({
          'email': email,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  Future<String?> register({
    required String email, 
    required String phone,
  }) async {
    // Validate registration inputs first
    String? validationError = validateRegistrationInputs();
    if (validationError != null) {
      return validationError;
    }

    // Check if passwords match
    if (passwordController.text != confirmPasswordController.text) {
      return 'Passwords do not match.';
    }

    // Validate email and phone
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (phone.isEmpty) {
      return 'Phone number is required.';
    }

    try {
      final response = await _dioClient.dio.post(
        'api/register.php',
        data: FormData.fromMap({
          'username': usernameController.text,
          'password': passwordController.text,
          'email': email,
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        if (response.data['error'] != null) {
          return response.data['error'];
        }
        return null;
      }
      return 'Registration failed.';
    } catch (e) {
      print('Error during registration: $e');
      return 'Registration failed due to network error.';
    }
  }

  String? validateInputs() {
    // Simple validation for login - just check if fields are not empty
    if (usernameController.text.isEmpty) {
      return 'Username is required.';
    }
    if (passwordController.text.isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  String? validateRegistrationInputs() {
    // Username validation
    if (usernameController.text.isEmpty) {
      return 'Username is required.';
    }
    if (usernameController.text.length < 5) {
      return 'Username must be at least 5 characters long.';
    }

    // Password validation
    if (passwordController.text.isEmpty) {
      return 'Password is required.';
    }
    if (passwordController.text.length < 10) {
      return 'Password must be at least 10 characters long.';
    }

    // Check for number
    if (!RegExp(r'[0-9]').hasMatch(passwordController.text)) {
      return 'Password must contain at least one number.';
    }

    // Check for uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(passwordController.text)) {
      return 'Password must contain at least one uppercase letter.';
    }

    // Check for lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(passwordController.text)) {
      return 'Password must contain at least one lowercase letter.';
    }

    // Check for symbol/special character
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(passwordController.text)) {
      return 'Password must contain at least one symbol.';
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
    if (_sessionToken == null) {
      print('No session token available for booking removal');
      return false;
    }

    try {
      print('Removing booking:');
      print('Day: $day, Time: $time');
      print('User: $loggedInUser, Role: $userRole');
      print('Session token: $_sessionToken');
      
      final response = await _dioClient.dio.post(
        'api/remove_booking.php',
        data: FormData.fromMap({
          'day': day,
          'time': time,
          'session_token': _sessionToken,
        }),
      );

      print('Remove booking response:');
      print('Status code: ${response.statusCode}');
      print('Body: ${response.data}');

      if (response.statusCode == 200) {
        // Even if we get a FormatException, the removal might have succeeded
        // So we'll check if the status code is 200 and update the local state
        final slotKey = '$day-$time';
        print('Booking removed successfully');
        print('Updating local state for slot: $slotKey');
        
        bookings[slotKey] = null;
        notifyListeners();
        return true;
      }
      
      print('HTTP error: ${response.statusCode}');
      return false;

    } catch (e) {
      print('Exception in removeBooking: $e');
      // The operation might have succeeded even if we got a parse error
      // So we'll return true to ensure UI updates properly
      return true;
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

  Future<bool> requestSlots({
    required List<Map<String, String>> slots,
    String description = '',
  }) async {
    try {
      if (selectedLab == null) {
        print('Error: No lab selected');
        return false;
      }

      print('Requesting slots with data:');
      print('Username: $loggedInUser');
      print('Lab: $selectedLab');
      print('Slots: $slots');
      print('Description: $description');

      final response = await _dioClient.dio.post(
        'api/request_slot.php',
        data: {
          'username': loggedInUser,
          'room_name': selectedLab,
          'slots': slots,
          'description': description,
        },
      );

      print('Response received:');
      print('Status code: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          // Check if there were any successful slots
          bool hadSuccess = data['slots'] != null && (data['slots'] as List).isNotEmpty;
          
          // Log failed slots but don't treat them as a complete failure
          if (data['failed_slots'] != null && (data['failed_slots'] as List).isNotEmpty) {
            print('Some slots failed:');
            for (var slot in data['failed_slots']) {
              print('Failed - Date: ${slot['date']}, Time: ${slot['time']}, Reason: ${slot['reason']}');
            }
          }
          
          // Update local state for successful slots
          if (hadSuccess) {
            print('Updating local state for successful slots');
            for (var slot in data['slots']) {
              String key = '${slot['date']}-${slot['time']}';
              print('Updating state for slot: $key');
              requests[key] = loggedInUser;
              if (description.isNotEmpty) {
                descriptions[key] = description;
              }
            }
            notifyListeners();
          }
          
          // Return true if any slots were successful
          return hadSuccess;
        } else {
          print('Request failed: ${data['error']}');
          if (data['details'] != null) {
            print('Details: ${data['details']}');
          }
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error requesting slots: $e');
      return false;
    }
  }

  Future<bool> requestSlot(String day, String time, {String description = ''}) async {
    print('Requesting slot: day=$day, time=$time, username=$loggedInUser, description=$description');
    try {
      return requestSlots(
        slots: [{'date': day, 'time': time}],
        description: description,
      );
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

  // Cancel a pending request
  Future<bool> cancelRequest(String day, String time) async {
    try {
      if (selectedLab == null) {
        print('Error: No lab selected');
        return false;
      }

      final response = await _dioClient.dio.post(
        'api/cancel_request.php',
        data: FormData.fromMap({
          'username': loggedInUser,
          'day': day,
          'time': time,
          'room_name': selectedLab,
        }),
      );

      print('Cancel request response:');
      print('Status code: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local state
        String key = '$day-$time';
        requests.remove(key);
        descriptions.remove(key);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error cancelling request: $e');
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
