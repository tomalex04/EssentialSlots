import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:lab_management/widgets/app_settings_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> times = ['1', '2', '3', '4', '5', '6'];
  final List<String> Hour = [
    '9-10',
    '10-11',
    '11-12',
    '12.45-1.45',
    '1.45-2.45',
    '2.45-3.45'
  ];
  final Set<String> selectedSlots = {};
  final TextEditingController _descriptionController = TextEditingController();
  bool isBooking = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.fetchLabs();
    for (var date in generateNext10Days()) {
      for (var time in times) {
        authProvider.bookings['$date-$time'] = null;
      }
    }
  }

  List<String> generateNext10Days() {
    List<String> dates = [];
    DateTime now = DateTime.now();
    int count = 0;
    while (count < 10) {
      if (now.weekday != DateTime.saturday && now.weekday != DateTime.sunday) {
        dates.add('${now.day}-${now.month}-${now.year}-${now.weekday}');
        count++;
      }
      now = now.add(const Duration(days: 1));
    }
    return dates;
  }

  String getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      default:
        return '';
    }
  }

  void toggleBooking(String key) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Allow selecting a slot if:
    // 1. It's available (not booked and no pending requests), OR
    // 2. The user already has a request for this slot (to cancel it)
    if (authProvider.bookings[key] == null && 
        (authProvider.requests[key] == null || 
         authProvider.requests[key] == authProvider.loggedInUser)) {
      setState(() {
        if (selectedSlots.contains(key)) {
          selectedSlots.remove(key);
        } else {
          selectedSlots.add(key);
        }
      });
    } else if (authProvider.requests[key] != null && 
               authProvider.requests[key] != authProvider.loggedInUser) {
      // Inform the user that this slot already has a pending request from another user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This slot already has a pending request from ${authProvider.requests[key]}'),
          duration: Duration(seconds: 2),
        ),
      );
      // Return early, don't allow selection of this slot
      return;
    }
  }

  void submitBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;
    String description = _descriptionController.text.trim();
    List<String> failedSlots = [];

    // Before making requests, check if any slots already have pending requests
    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];
      
      // If someone else has already requested this slot, don't attempt to request it
      if (authProvider.requests[slot] != null && 
          authProvider.requests[slot] != authProvider.loggedInUser) {
        allSuccess = false;
        failedSlots.add('$day (Time: ${time})');
        continue;
      }
    }
    
    // If there are failed slots, notify the user and don't proceed
    if (!allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some slots already have pending requests: ${failedSlots.join(", ")}'),
          duration: Duration(seconds: 3),
        ),
      );
      // Refresh data to get the latest state
      await authProvider.fetchBookings();
      setState(() {
        selectedSlots.clear();
        isBooking = false;
        _descriptionController.clear();
      });
      return;
    }

    // Proceed with requesting the slots
    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];

      bool success = await authProvider.requestSlot(day, time, description: description);
      if (success) {
        setState(() {
          authProvider.requests[slot] = authProvider.loggedInUser;
          if (description.isNotEmpty) {
            authProvider.descriptions[slot] = description;
          }
        });
      } else {
        allSuccess = false;
        failedSlots.add('$day (Time: ${time})');
      }
    }

    // Refresh data
    authProvider.fetchBookings();

    if (allSuccess) {
      setState(() {
        selectedSlots.clear();
        isBooking = false;
        _descriptionController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot requests submitted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some requests failed: ${failedSlots.join(", ")}. The slots may already be requested by another user.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void cancelBooking() {
    setState(() {
      selectedSlots.clear();
      isBooking = false;
      _descriptionController.clear();
    });
  }

  void logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _onRefresh() async {
    // Simulate a delay for fetching new data
    await Future.delayed(Duration(seconds: 2));
    final authProvider = Provider.of<AuthProvider>(context,
        listen: false); // Perform any refresh logic here
    authProvider.fetchBookings();
    setState(() {
      selectedSlots.clear();
      isBooking = false;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.fetchBookings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing data...')),
              );
            },
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
                  Spacer(),
                  Text(
                    '${authProvider.loggedInUser}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Request Slot'),
              onTap: () {
                setState(() {
                  isBooking = true;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: logout,
            ),
            const Divider(),
            const AppSettingsControls(),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: authProvider.selectedLab,
              hint: const Text('Select Lab'),
              isExpanded: true,
              items: authProvider.availableLabs.map((String lab) {
                return DropdownMenuItem<String>(
                  value: lab,
                  child: Text(lab),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  authProvider.selectedLab = newValue;
                  authProvider.fetchBookings();
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    if (isBooking) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a short description (optional)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          maxLength: 100,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: submitBooking,
                            child: const Text('Request Selected'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: cancelBooking,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Table(
                          border: TableBorder.all(),
                          children: [
                            TableRow(
                              children: [
                                const TableCell(child: Center(child: Text(''))),
                                ...List.generate(
                                    6,
                                    (index) => TableCell(
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text('Hour ${times[index]}'),
                                                Text(Hour[index]),
                                              ],
                                            ),
                                          ),
                                        )),
                              ],
                            ),
                            ...generateNext10Days().map((date) {
                              final parts = date.split('-');
                              final day = parts[0];
                              final month = parts[1];
                              final year = parts[2];
                              final weekday = int.parse(parts[3]);
                              return TableRow(
                                children: [
                                  TableCell(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('$day-$month-$year'),
                                          Text(getDayName(weekday)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ...times.map((time) {
                                    String key = '$day-$month-$year-$time';
                                    return TableCell(
                                      child: GestureDetector(
                                          onTap: () {
                                            if (isBooking) {
                                              toggleBooking(key);
                                            }
                                          },
                                          child: Container(
                                            color: selectedSlots.contains(key)
                                                ? Colors.blue.withOpacity(0.5)
                                                : authProvider.bookings[key] ==
                                                        'Deactivated by Admin'
                                                    ? Colors.grey // Deactivated slots
                                                    : authProvider.bookings[key] != null
                                                        ? Colors.red // Booked slots - always red for all users
                                                        : authProvider.requests[key] != null
                                                            ? Colors.yellow // Requested slots - always yellow
                                                            : Colors.green, // Available slots
                                            height: 50,
                                            child: Center(
                                              child: Text(
                                                authProvider.bookings[key] ==
                                                        'Deactivated by Admin'
                                                    ? 'Deactivated'
                                                    : authProvider.bookings[key] != null
                                                        ? authProvider.descriptions[key] != null && authProvider.descriptions[key]!.isNotEmpty
                                                            ? '${authProvider.bookings[key]}: ${authProvider.descriptions[key]}'
                                                            : 'Booked by ${authProvider.bookings[key]}'
                                                        : authProvider.requests[key] != null
                                                            ? 'Request by ${authProvider.requests[key]}'
                                                            : 'Available',
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
