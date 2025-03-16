import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<String> selectedDates = [];
  final List<String> times = ['1', '2', '3', '4', '5', '6'];
  final List<String> Hour = [
    '9-10',
    '10-11',
    '11-12',
    '12.45-1.45',
    '1.45-2.45',
    '2.45-3.45'
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.fetchLabs();
  }

  final Set<String> selectedSlots = {};
  bool isDeactivating = false;
  bool isBooking = false;
  final TextEditingController _labNameController = TextEditingController();

  void selectDateRange() {
    if (fromDate != null && toDate != null) {
      selectedDates.clear();
      DateTime currentDate = fromDate!;
      while (currentDate.isBefore(toDate!) ||
          currentDate.isAtSameMomentAs(toDate!)) {
        selectedDates.add(
            '${currentDate.day}-${currentDate.month}-${currentDate.year}-${currentDate.weekday}');
        currentDate = currentDate.add(const Duration(days: 1));
      }
      setState(() {});
    }
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
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
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

  void toggleActivation(String key) {
    //final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      if (selectedSlots.contains(key)) {
        selectedSlots.remove(key);
      } else {
        selectedSlots.add(key);
      }
    });
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
    // Fetch updated bookings after processing
    authProvider.fetchBookings();
  }

  void submitActivation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;

    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day =
          '${parts[0]}-${parts[1]}-${parts[2]}'; // Ensure full date format
      final time = parts[3];

      // Call activateSlot and handle response
      bool success = await authProvider.activateSlot(day, time);
      //print('Activation result for $day-$time: $success');

      if (!success) {
        allSuccess = false;
      }
    }

    if (allSuccess) {
      setState(() {
        selectedSlots.clear();
        isDeactivating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All slots successfully updated'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some activations failed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    // Fetch updated bookings after processing
    authProvider.fetchBookings();
  }

  void cancelChanges() {
    setState(() {
      selectedSlots.clear();
      isBooking = false;
      isDeactivating = false;
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
      isDeactivating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    print('AdminHomeScreen build - Selected Lab: ${authProvider.selectedLab}');
    print('AdminHomeScreen build - Bookings: ${authProvider.bookings}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Home'),
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
              decoration: BoxDecoration(
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
              title: const Text('Deactivate Days/Cells'),
              onTap: () {
                setState(() {
                  isDeactivating = true;
                  isBooking = false;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Book Days/Cells'),
              onTap: () {
                setState(() {
                  isBooking = true;
                  isDeactivating = false;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Add New Lab'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Add New Lab'),
                    content: TextField(
                      controller: _labNameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter lab name',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (_labNameController.text.isNotEmpty) {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final success = await authProvider.addLab(_labNameController.text);
                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lab added successfully')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to add lab')),
                              );
                            }
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Lab Details'),
              onTap: () {
                Navigator.pushNamed(context, '/lab-management');
              },
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: logout,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'From'),
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            fromDate = pickedDate;
                          });
                        }
                      },
                      controller: TextEditingController(
                        text: fromDate != null
                            ? '${fromDate!.day}-${fromDate!.month}-${fromDate!.year}'
                            : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'To'),
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            toDate = pickedDate;
                          });
                        }
                      },
                      controller: TextEditingController(
                        text: toDate != null
                            ? '${toDate!.day}-${toDate!.month}-${toDate!.year}'
                            : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: selectDateRange,
                    child: const Text('Submit'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isDeactivating || isBooking)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed:
                          isDeactivating ? submitActivation : submitBooking,
                      child: const Text('Submit Selected'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: cancelChanges,
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
                          const TableCell(child: Center(child: Text('Date'))),
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
                      ...selectedDates.map((date) {
                        final parts = date.split('-');
                        final day = parts[0];
                        final month = parts[1];
                        final year = parts[2];
                        final weekday = int.parse(parts[3]);
                        return TableRow(
                          children: [
                            TableCell(
                              child: GestureDetector(
                                onTap: () {
                                  if (isDeactivating) {
                                    toggleActivation('$day-$month-$year');
                                  } else if (isBooking) {
                                    toggleBooking('$day-$month-$year');
                                  }
                                },
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('$day-$month-$year'),
                                      Text(getDayName(weekday)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ...times.map((time) {
                              String key = '$day-$month-$year-$time';
                              //print(key);
                              return TableCell(
                                child: GestureDetector(
                                  onTap: () {
                                    if (isDeactivating) {
                                      toggleActivation(key);
                                    } else if (isBooking) {
                                      toggleBooking(key);
                                    }
                                  },
                                  child: Container(
                                    color: selectedSlots.contains(key)
                                        ? Colors.blue.withOpacity(0.5)
                                        : authProvider.bookings[key] ==
                                                'Deactivated by Admin'
                                            ? Colors.grey
                                            : authProvider.bookings[key] == null
                                                ? Colors.green
                                                : authProvider.bookings[key] ==
                                                        authProvider
                                                            .loggedInUser
                                                    ? Colors.red
                                                    : Colors
                                                        .yellow, // This should reflect if it is booked by another user
                                    height: 50,
                                    child: Center(
                                      child: Text(
                                        authProvider.bookings[key] ==
                                                'Deactivated by Admin'
                                            ? 'Deactivated by Admin'
                                            : authProvider.bookings[key] != null
                                                ? 'Booked by ${authProvider.bookings[key]}'
                                                : 'Available',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
