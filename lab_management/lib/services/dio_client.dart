import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DioClient {
  late Dio dio;
  static const String serverIP = '10.201.1.100:81'; // Change this to your server IP or domain
//10.201.1.100:81
  Future<void> init() async {
    dio = Dio(BaseOptions(
      baseUrl: 'http://$serverIP/lab-management-backend/',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
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