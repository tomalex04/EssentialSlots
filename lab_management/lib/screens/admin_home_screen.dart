import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:lab_management/widgets/app_settings_controls.dart';

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
  bool isRemoving = false;
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

  void toggleRemoval(String key) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Only allow selection of slots that have bookings (not deactivated or empty)
    if (authProvider.bookings[key] != null && 
        authProvider.bookings[key] != 'Deactivated by Admin') {
      setState(() {
        if (selectedSlots.contains(key)) {
          selectedSlots.remove(key);
        } else {
          selectedSlots.add(key);
        }
      });
    }
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

  void submitRemoval() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;
    List<String> removedSlots = [];

    // Show confirmation dialog
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Removal'),
          content: Text('Are you sure you want to remove ${selectedSlots.length} booking(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmed) return;

    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];

      bool success = await authProvider.removeBooking(day, time);
      if (success) {
        removedSlots.add(slot);
      } else {
        allSuccess = false;
      }
    }

    if (allSuccess && removedSlots.isNotEmpty) {
      setState(() {
        selectedSlots.clear();
        isRemoving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedSlots.length} booking(s) removed successfully'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (removedSlots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedSlots.length} booking(s) removed, but some failed'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove bookings'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Fetch updated bookings after processing
    authProvider.fetchBookings();
  }

  void cancelChanges() {
    setState(() {
      selectedSlots.clear();
      isDeactivating = false;
      isRemoving = false;
    });
  }

  Future<void> logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
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
      isDeactivating = false;
      isRemoving = false;
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
              title: const Text('Deactivate/Activate Slots'),
              onTap: () {
                setState(() {
                  isDeactivating = true;
                  isRemoving = false;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Remove Bookings'),
              onTap: () {
                setState(() {
                  isRemoving = true;
                  isDeactivating = false;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('View Pending Requests'),
              onTap: () {
                Navigator.of(context).pushNamed('/requests');
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
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            final success = await authProvider
                                .addLab(_labNameController.text);
                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Lab added successfully')),
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
              title: const Text('Logout'),
              onTap: logout,
            ),
            const Divider(),
            const AppSettingsControls(),
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
              if (isDeactivating || isRemoving)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: isDeactivating 
                          ? submitActivation 
                          : submitRemoval,
                      child: Text(isDeactivating 
                          ? 'Submit Selected' 
                          : 'Remove Selected'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: isRemoving ? Colors.white : null,
                        backgroundColor: isRemoving ? Colors.red : null,
                      ),
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
                                  } else if (isRemoving) {
                                    toggleRemoval('$day-$month-$year');
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
                                    } else if (isRemoving) {
                                      toggleRemoval(key);
                                    }
                                  },
                                  child: Container(
                                    color: selectedSlots.contains(key)
                                        ? Colors.blue.withOpacity(0.5)
                                        : authProvider.bookings[key] ==
                                                'Deactivated by Admin'
                                            ? Colors.grey // Deactivated slots
                                            : authProvider.bookings[key] != null
                                                ? Colors.red // All booked slots are red
                                                : authProvider.requests[key] != null
                                                    ? Colors.yellow // All pending requests are yellow
                                                    : Colors.green, // Available slots
                                    height: 50,
                                    child: Center(
                                      child: Text(
                                        authProvider.bookings[key] ==
                                                'Deactivated by Admin'
                                            ? 'Deactivated by Admin'
                                            : authProvider.bookings[key] != null
                                                ? 'Booked by ${authProvider.bookings[key]}'
                                                : authProvider.requests[key] != null
                                                    ? 'Request by ${authProvider.requests[key]}'
                                                    : 'Available',
                                        textAlign: TextAlign.center,
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
