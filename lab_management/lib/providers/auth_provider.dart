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
    _initDio();
  }

  Future<void> _initDio() async {
    _dioClient = DioClient();
    await _dioClient.init();
    
    // Check for existing session token
    await _loadStoredSession();
    
    // After initializing Dio, fetch the labs
    await fetchLabs();
    if (availableLabs.isNotEmpty) {
      selectedLab = availableLabs[0];
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
      return;
    }
    try {
      final response = await _dioClient.dio.post(
        'api/fetch_bookings.php',
        data: FormData.fromMap({
          'room_name': selectedLab,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        bookings.clear();
        requests.clear(); // Clear requests map
        descriptions.clear(); // Clear descriptions map

        data['bookings'].forEach((booking) {
          String key = '${booking['day']}-${booking['time']}';

          bookings[key] = booking['username'];
          if (booking['description'] != null) {
            descriptions[key] = booking['description'];
          }
        });

        data['deactivations'].forEach((deactivation) {
          String key = '${deactivation['day']}-${deactivation['time']}';

          bookings[key] = 'Deactivated by Admin';
        });

        // Also fetch requests for the same lab
        await fetchRequests();


        notifyListeners();
      }
    } catch (e) {
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
    }
  }

  Future<void> fetchLabs() async {
    try {
      final response = await _dioClient.dio.get('api/fetch_labs.php');

      if (response.statusCode == 200) {
        final data = response.data;
        availableLabs = List<String>.from(data['labs']);
        notifyListeners();
      }
    } catch (e) {
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

      if (response.statusCode != 200) {
        return 'Login failed. Please try again.';
      }

      final responseData = response.data;
      if (responseData['message'] != 'Login successful') {
        return responseData['error'] ?? 'Login failed. Please try again.';
      }

      // Login successful
      loggedInUser = usernameController.text;
      
      // Store session token
      if (responseData['session_token'] == null) {
        return 'Login failed: Server error';
      }
      
      await _storeSessionToken(responseData['session_token']);
      
      // Get user role
      try {
        final roleSuccess = await _fetchUserRole();
        if (!roleSuccess) {
          await _clearSessionToken();
          return 'Login failed: Could not determine user role';
        }
        
        // Fetch labs and bookings after successful login
        await fetchLabs();
        if (availableLabs.isNotEmpty) {
          selectedLab = availableLabs[0];
          await fetchBookings();
        }
        
        notifyListeners();
        return null;
        
      } catch (e) {
        await _clearSessionToken();
        return 'Login failed: Could not get user role';
      }
      
    } catch (e) {
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
      return false;
    }

    try {
      final response = await _dioClient.dio.post(
        'api/get_user_role.php',
        data: FormData.fromMap({
          'session_token': _sessionToken,
        }),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 'success' && data['role'] != null) {
          userRole = data['role'].toString();
          return true;
        } else {
          userRole = null;
        }
      } else {
        userRole = null;
      }
    } catch (e) {
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
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeBooking(String day, String time) async {
    if (_sessionToken == null) {
      return false;
    }

    try {
      
      final response = await _dioClient.dio.post(
        'api/remove_booking.php',
        data: FormData.fromMap({
          'day': day,
          'time': time,
          'session_token': _sessionToken,
        }),
      );

      if (response.statusCode == 200) {
        // Even if we get a FormatException, the removal might have succeeded
        // So we'll check if the status code is 200 and update the local state
        final slotKey = '$day-$time';
        
        bookings[slotKey] = null;
        notifyListeners();
        return true;
      }
      
      return false;

    } catch (e) {
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
      return false;
    }
  }

  Future<bool> requestSlots({
    required List<Map<String, String>> slots,
    String description = '',
  }) async {
    try {
      if (selectedLab == null) {
        return false;
      }

      final response = await _dioClient.dio.post(
        'api/request_slot.php',
        data: {
          'username': loggedInUser,
          'room_name': selectedLab,
          'slots': slots,
          'description': description,
        },
      );



      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          // Check if there were any successful slots
          bool hadSuccess = data['slots'] != null && (data['slots'] as List).isNotEmpty;
          
          // Log failed slots but don't treat them as a complete failure
          if (data['failed_slots'] != null && (data['failed_slots'] as List).isNotEmpty) {
          }
          
          // Update local state for successful slots
          if (hadSuccess) {
            for (var slot in data['slots']) {
              String key = '${slot['date']}-${slot['time']}';
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
          return false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestSlot(String day, String time, {String description = ''}) async {
    try {
      return requestSlots(
        slots: [{'date': day, 'time': time}],
        description: description,
      );
    } catch (e) {
      return false;
    }
  }

  // New method to handle request approvals/rejections
  Future<bool> handleRequest(int requestId, String action) async {
    try {
      final response = await _dioClient.dio.post(
        'api/handle_request.php',
        data: FormData.fromMap({
          'request_id': requestId.toString(),
          'action': action,
          'admin_username': loggedInUser,
        }),
      );



      final responseData = response.data;

      if (responseData['message'] != null && !responseData['message'].toString().contains('failed')) {
        // Refresh data to show the latest state
        await fetchBookings();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Cancel a pending request
  Future<bool> cancelRequest(String day, String time) async {
    try {
      if (selectedLab == null) {
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
