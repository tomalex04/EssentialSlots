import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DioClient {
  late Dio dio;
  static const String serverIP = '192.168.1.41';

  Future<void> init() async {
    dio = Dio(BaseOptions(
      baseUrl: 'http://$serverIP/lab-management-backend/',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      contentType: 'application/x-www-form-urlencoded',
      validateStatus: (status) {
        return status! < 500;
      },
    ));

    // Configure Dio for web CORS
    if (kIsWeb) {
      dio.options.extra = {'withCredentials': true};
      dio.options.headers['Accept'] = '*/*';
      
      // Intercept requests to handle CORS
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          print('Making request to: ${options.uri}');
          print('Request headers: ${options.headers}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('Received response: ${response.statusCode}');
          print('Response headers: ${response.headers}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('Request error: ${error.message}');
          print('Response: ${error.response}');
          return handler.next(error);
        },
      ));
    }

    // Add interceptor for logging
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: true,
    ));
  }

  void clearCookies() {
    // Clear cookies if needed
  }
}