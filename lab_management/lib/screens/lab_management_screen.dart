import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FilePickerResult, FileType, PlatformFile;
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LabManagementScreen extends StatefulWidget {
  const LabManagementScreen({super.key});

  @override
  _LabManagementScreenState createState() => _LabManagementScreenState();
}

class _LabManagementScreenState extends State<LabManagementScreen> {
  String? selectedLab;
  List<String> files = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.fetchLabs();
  }

  Future<void> fetchFiles(String labName) async {
    try {
      final response = await http.get(Uri.parse('http://localhost/lab-management-backend/api/fetch_files.php?lab_name=$labName'));
      if (response.statusCode == 200) {
        setState(() {
          files = List<String>.from(jsonDecode(response.body));
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load files';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> deleteFile(String labName, String fileName) async {
    try {
      final response = await http.delete(Uri.parse('http://localhost/lab-management-backend/api/delete_file.php?lab_name=$labName&file_name=$fileName'));
      if (response.statusCode == 200) {
        fetchFiles(labName);
      } else {
        setState(() {
          errorMessage = 'Failed to delete file';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> uploadFile(String labName) async {
    try {
      String? filePath;
      String? fileName;
      List<int>? fileBytes;
      
      // On desktop platforms, always use file_selector
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        final textTypeGroup = XTypeGroup(
          label: 'Text documents',
          extensions: ['txt', 'text'],
          mimeTypes: ['text/plain'],
          uniformTypeIdentifiers: ['public.plain-text', 'public.text'],
        );
        
        final XFile? file = await openFile(
          acceptedTypeGroups: [textTypeGroup],
          confirmButtonText: 'Select Document',
        );
        
        if (file != null) {
          filePath = file.path;
          fileName = file.name;
        }
      } 
      // On web and mobile platforms, use file_picker which works better there
      else {
        try {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['txt', 'text'],
          );
          
          if (result != null) {
            fileName = result.files.single.name;
            
            // On web, we get bytes directly
            if (kIsWeb) {
              fileBytes = result.files.single.bytes;
            } 
            // On mobile, we get a file path
            else {
              filePath = result.files.single.path;
            }
          }
        } catch (e) {
          // If file_picker fails for any reason, fall back to file_selector
          print("FilePicker failed, falling back to XFile: $e");
          final textTypeGroup = XTypeGroup(
            label: 'Text documents',
            extensions: ['txt', 'text'],
            mimeTypes: ['text/plain'],
          );
          
          final XFile? file = await openFile(acceptedTypeGroups: [textTypeGroup]);
          if (file != null) {
            filePath = file.path;
            fileName = file.name;
            if (kIsWeb) {
              fileBytes = await file.readAsBytes();
            }
          }
        }
      }
      
      // If we have a file, upload it
      if ((filePath != null || fileBytes != null) && fileName != null) {
        // Show a loading indicator
        setState(() {
          errorMessage = "Uploading file...";
        });
        
        var request = http.MultipartRequest('POST', Uri.parse('http://localhost/lab-management-backend/api/upload_file.php'));
        request.fields['lab_name'] = labName;
        
        // For web platform, we use bytes
        if (kIsWeb && fileBytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName
          ));
        } 
        // For other platforms, we use file path
        else if (filePath != null) {
          request.files.add(await http.MultipartFile.fromPath('file', filePath));
        }

        var response = await request.send();
        var responseData = await http.Response.fromStream(response);
        var responseBody = jsonDecode(responseData.body);

        if (response.statusCode == 200 && responseBody['message'] != null) {
          fetchFiles(labName);
          setState(() {
            errorMessage = null;
          });
        } else {
          setState(() {
            errorMessage = responseBody['error'] ?? 'Failed to upload file';
          });
        }
      } else {
        // User canceled file selection or another error occurred
        print("No file was selected");
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error selecting or uploading file: $e';
      });
      print("File upload error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Management'),
      ),
      body: Column(
        children: [
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          DropdownButton<String>(
            hint: const Text('Select Lab'),
            value: selectedLab,
            onChanged: (String? newValue) {
              setState(() {
                selectedLab = newValue;
                fetchFiles(newValue!);
              });
            },
            items: authProvider.availableLabs.map<DropdownMenuItem<String>>((String lab) {
              return DropdownMenuItem<String>(
                value: lab,
                child: Text(lab),
              );
            }).toList(),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(files[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      deleteFile(selectedLab!, files[index]);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0), // Add padding below the button
            child: ElevatedButton(
              onPressed: () {
                if (selectedLab != null) {
                  uploadFile(selectedLab!);
                } else {
                  setState(() {
                    errorMessage = 'Please select a lab first';
                  });
                }
              },
              child: const Text('Add File'),
            ),
          ),
        ],
      ),
    );
  }
}