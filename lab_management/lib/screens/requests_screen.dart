import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:lab_management/widgets/app_settings_controls.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  _RequestsScreenState createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRequests();
    });
  }

  Future<void> _refreshRequests() async {
    setState(() {
      isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.fetchRequests();

    setState(() {
      isLoading = false;
    });
  }

  String _formatDayDisplay(String day) {
    // Convert day format (e.g., "3-2-2025") to a more readable format
    final parts = day.split('-');
    if (parts.length >= 3) {
      return '${parts[0]}/${parts[1]}/${parts[2]}';
    }
    return day;
  }

  String _formatTimeSlot(String time) {
    // Convert time slot number to readable time with hour number
    switch (time) {
      case '1':
        return 'Hour 1: 9:00 - 10:00';
      case '2':
        return 'Hour 2: 10:00 - 11:00';
      case '3':
        return 'Hour 3: 11:00 - 12:00';
      case '4':
        return 'Hour 4: 12:45 - 1:45';
      case '5':
        return 'Hour 5: 1:45 - 2:45';
      case '6':
        return 'Hour 6: 2:45 - 3:45';
      default:
        return 'Slot $time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final requests = authProvider.pendingRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        actions: [
          TextButton(
            child: const Text('Refresh'),
            onPressed: _refreshRequests,
          ),
          Builder(
            builder: (context) => TextButton(
              child: const Text('Settings'),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${Provider.of<AuthProvider>(context).loggedInUser}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            const AppSettingsControls(),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final requestId = request[0];
                    final username = request[1];
                    final day = request[2];
                    final time = request[3];
                    final description = request.length > 4 ? request[4] : '';
                    final competingRequests =
                        request.length > 5 ? request[5] : 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request from: $username',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Date: ${_formatDayDisplay(day.toString())}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Time: ${_formatTimeSlot(time.toString())}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Description: $description',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                            if (competingRequests > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: $competingRequests other ${competingRequests == 1 ? 'user has' : 'users have'} requested this slot',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final success =
                                        await authProvider.handleRequest(
                                      requestId,
                                      'reject',
                                    );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Request rejected'),
                                        ),
                                      );
                                      _refreshRequests();
                                    }
                                  },
                                  child: const Text('Reject'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final success =
                                        await authProvider.handleRequest(
                                      requestId,
                                      'approve',
                                    );
                                    if (success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Request approved'),
                                          duration: const Duration(milliseconds: 500),
                                        ),
                                      );
                                      _refreshRequests();
                                    }
                                  },
                                  child: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
