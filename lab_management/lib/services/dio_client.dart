import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;
  late CookieJar cookieJar;
  bool _isInitialized = false;

  factory DioClient() {
    return _instance;
  }

  DioClient._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost/lab-management-backend/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/x-www-form-urlencoded',
      validateStatus: (status) {
        return status != null && status < 500;
      },
    ));

    // Set up persistent cookie storage
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage("$appDocPath/.cookies/"),
    );
    
    dio.interceptors.add(CookieManager(cookieJar));
    
    // Add logging interceptor in debug mode
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }
    
    _isInitialized = true;
  }

  // Method to clear all cookies (useful for logout)
  Future<void> clearCookies() async {
    await cookieJar.deleteAll();
  }
}