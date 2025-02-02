import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';

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
    if (authProvider.bookings[key] == null ||
        authProvider.bookings[key] == authProvider.loggedInUser) {
      setState(() {
        if (selectedSlots.contains(key)) {
          selectedSlots.remove(key);
        } else {
          selectedSlots.add(key);
        }
      });
    }
  }

  void submitBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;

    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day =
          '${parts[0]}-${parts[1]}-${parts[2]}'; // Ensure full date format
      final time = parts[3];

      bool success = await authProvider.bookSlot(day, time);
      if (success) {
        setState(() {
          authProvider.bookings[slot] = authProvider.loggedInUser;
        });
      } else {
        allSuccess = false;
      }
      authProvider.fetchBookings();
    }

    if (allSuccess) {
      setState(() {
        selectedSlots.clear();
        isBooking = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some bookings failed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void cancelBooking() {
    setState(() {
      selectedSlots.clear();
      isBooking = false;
    });
  }

  void logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.loggedInUser = null;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
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
              title: const Text('Book Cell'),
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
                    if (isBooking)
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: submitBooking,
                            child: const Text('Book Selected'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: cancelBooking,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
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
                                                    ? Colors
                                                        .grey // Ensure this check comes first
                                                    : authProvider.bookings[key] ==
                                                            null
                                                        ? Colors.green
                                                        : authProvider
                                                                    .bookings[
                                                                key] ==
                                                            authProvider
                                                                .loggedInUser
                                                            ? Colors.red
                                                            : Colors.yellow,
                                            height: 50,
                                            child: Center(
                                              child: Text(
                                                authProvider.bookings[key] ==
                                                        'Deactivated by Admin'
                                                    ? 'Deactivated by Admin'
                                                    : authProvider.bookings[key] !=
                                                            null
                                                        ? 'Booked by ${authProvider.bookings[key]}'
                                                        : 'Available',
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
