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

  // New state variables for request functionality
  bool isRequesting = false;
  final TextEditingController _descriptionController = TextEditingController();
  // Existing variables
  final Set<String> selectedSlots = {};
  bool isDeactivating = false;
  bool isRemoving = false;
  final TextEditingController _labNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.fetchLabs();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _labNameController.dispose();
    super.dispose();
  }

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

    if (isRequesting) {
      // For requesting: allow selecting available slots and toggling own requests
      if (authProvider.bookings[key] == null) {
        setState(() {
          if (selectedSlots.contains(key)) {
            selectedSlots.remove(key);
          } else {
            // If we already requested this slot, mark it for cancellation
            if (authProvider.requests[key] == authProvider.loggedInUser) {
              selectedSlots.add(key);
            }
            // If slot is available, mark it for requesting
            else if (authProvider.requests[key] == null) {
              selectedSlots.add(key);
            }
            // If someone else requested it, show a message
            else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'This slot is already requested by ${authProvider.requests[key]}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        });
      }
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
              content: Text(
                  'Are you sure you want to remove ${selectedSlots.length} booking(s)?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;

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
          content:
              Text('${removedSlots.length} booking(s) removed successfully'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (removedSlots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${removedSlots.length} booking(s) removed, but some failed'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove bookings'),
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
    await Future.delayed(const Duration(seconds: 1));
    final authProvider = Provider.of<AuthProvider>(context,
        listen: false); // Perform any refresh logic here
    authProvider.fetchBookings();
    setState(() {
      selectedSlots.clear();
      isDeactivating = false;
      isRemoving = false;
      isRequesting = false;
      _descriptionController.clear();
    });
  }

  void cancelRequest() {
    setState(() {
      selectedSlots.clear();
      isRequesting = false;
      _descriptionController.clear();
    });
  }

  void submitRequest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;
    List<String> slotsToRequest = [];
    List<String> slotsToCancel = [];
    List<String> failedSlots = [];
    String description = _descriptionController.text.trim();

    // Split selected slots into requests and cancellations
    for (var slot in selectedSlots) {
      if (authProvider.requests[slot] == authProvider.loggedInUser) {
        slotsToCancel.add(slot);
      } else {
        slotsToRequest.add(slot);
      }
    }

    // For new requests only, validate description
    if (slotsToRequest.isNotEmpty &&
        slotsToCancel.isEmpty &&
        description.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description is required for new requests'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Reset UI state immediately regardless of what happens next
    setState(() {
      selectedSlots.clear();
      isRequesting = false;
      _descriptionController.clear();
    });

    // Process cancellations first
    for (var slot in slotsToCancel) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];

      bool success = await authProvider.cancelRequest(day, time);
      if (!success) {
        allSuccess = false;
        failedSlots.add('$day (Time: $time) - Cancel failed');
      }
    }

    // Process new requests
    if (slotsToRequest.isNotEmpty) {
      // Optimistically update UI
      for (var slot in slotsToRequest) {
        authProvider.requests[slot] = authProvider.loggedInUser;
        if (description.isNotEmpty) {
          authProvider.descriptions[slot] = description;
        }
      }
      // Show processing indicator only if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing requests...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Make the actual request
      bool batchSuccess = await authProvider.requestSlots(
        slots: slotsToRequest.map((slot) {
          final parts = slot.split('-');
          return {
            'date': '${parts[0]}-${parts[1]}-${parts[2]}',
            'time': parts[3]
          };
        }).toList(),
        description: description,
      );

      if (!batchSuccess) {
        // If request failed, revert the optimistic updates
        for (var slot in slotsToRequest) {
          authProvider.requests.remove(slot);
          authProvider.descriptions.remove(slot);
          final parts = slot.split('-');
          final day = '${parts[0]}-${parts[1]}-${parts[2]}';
          final time = parts[3];
          failedSlots.add('$day (Time: $time) - Request failed');
        }
        allSuccess = false;
      }
    }

    // Refresh data
    await authProvider.fetchBookings();

    // Show feedback based on what was successful
    List<String> messages = [];
    if (!allSuccess) {
      // Some failures occurred
      if (failedSlots.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some actions failed: ${failedSlots.join(", ")}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Everything was successful
      if (slotsToRequest.isNotEmpty) {
        messages.add('${slotsToRequest.length} slot(s) requested');
      }
      if (slotsToCancel.isNotEmpty) {
        messages.add('${slotsToCancel.length} request(s) cancelled');
      }
      if (messages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messages.join('. ')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void toggleRow(String date) {
    if (!isDeactivating && !isRemoving && !isRequesting) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allSlotsInRow = times.map((time) => '$date-$time').toList();
    bool shouldSelect = false;

    // Check if we should select or deselect based on the first available slot
    if (isRequesting) {
      // For requesting mode, check if any slot can be requested
      shouldSelect = allSlotsInRow.any((key) =>
          !selectedSlots.contains(key) &&
          (authProvider.bookings[key] == null && authProvider.requests[key] == null));
    } else if (isDeactivating) {
      // For deactivating mode, check if any slot is not yet selected
      shouldSelect = allSlotsInRow.any((key) => !selectedSlots.contains(key));
    } else if (isRemoving) {
      // For removing mode, check if any booked slot is not yet selected
      shouldSelect = allSlotsInRow.any((key) =>
          !selectedSlots.contains(key) &&
          authProvider.bookings[key] != null &&
          authProvider.bookings[key] != 'Deactivated by Admin');
    }

    setState(() {
      for (String key in allSlotsInRow) {
        if (shouldSelect) {
          // Add slots based on the current mode
          if (isRequesting) {
            if (authProvider.bookings[key] == null &&
                authProvider.requests[key] == null) {
              selectedSlots.add(key);
            }
          } else if (isDeactivating) {
            selectedSlots.add(key);
          } else if (isRemoving) {
            if (authProvider.bookings[key] != null &&
                authProvider.bookings[key] != 'Deactivated by Admin') {
              selectedSlots.add(key);
            }
          }
        } else {
          // Remove all slots in the row
          selectedSlots.remove(key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Column(
        children: [
          // Add padding above the banner image
          SizedBox(
            height: MediaQuery.of(context).size.height *
                0.05, // 2% of screen height
          ),
          // Banner image taking 10% of screen height
          Container(
            height: MediaQuery.of(context).size.height *
                0.1, // 10% of screen height
            width: double.infinity,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/IMG_8740.PNG',
              fit:
                  BoxFit.contain, // Changed to contain to maintain aspect ratio
              height: MediaQuery.of(context).size.height *
                  0.1, // Ensure image height matches container
            ),
          ),
          // Main content
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Admin Home'),
                actions: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
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
                          const Spacer(),
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
                          isRequesting = true;
                          isDeactivating = false;
                          isRemoving = false;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      title: const Text('Deactivate/Activate Slots'),
                      onTap: () {
                        setState(() {
                          isRequesting = false;
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
                          isRequesting = false;
                          isDeactivating = false;
                          isRemoving = true;
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
                      title: const Text('Add New Hall'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Add New Hall'),
                            content: TextField(
                              controller: _labNameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter Hall name',
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
                                    final authProvider =
                                        Provider.of<AuthProvider>(context,
                                            listen: false);
                                    final success = await authProvider
                                        .addLab(_labNameController.text);
                                    if (success) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Hall added successfully')),
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
                  if (isDeactivating || isRemoving || isRequesting)
                    Column(
                      children: [
                        if (isRequesting)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            child: TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                hintText:
                                    'Enter a short description (required)',
                                labelText: 'Description *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              maxLength: 100,
                            ),
                          ),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: isDeactivating
                                  ? submitActivation
                                  : isRemoving
                                      ? submitRemoval
                                      : submitRequest,
                              style: ElevatedButton.styleFrom(
                                foregroundColor:
                                    isRemoving ? Colors.white : null,
                                backgroundColor: isRemoving ? Colors.red : null,
                              ),
                              child: Text(isDeactivating
                                  ? 'Submit Selected'
                                  : isRemoving
                                      ? 'Remove Selected'
                                      : 'Submit Changes'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed:
                                  isRequesting ? cancelRequest : cancelChanges,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(20.0),
                      minScale: 0.5,
                      maxScale: 2.0,
                      scaleEnabled: false, // Disable zooming with mouse wheel
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Container(
                            // Ensure the table takes enough width
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width,
                            ),
                            child: Table(
                              border: TableBorder.all(),
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              children: [
                                TableRow(
                                  children: [
                                    const TableCell(
                                        child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child:
                                                Center(child: Text('Date')))),
                                    ...List.generate(
                                      6,
                                      (index) => TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
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
                                        ),
                                      ),
                                    ),
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
                                          onTap: () => toggleRow('$day-$month-$year'),
                                          child: Container(
                                            color: isDeactivating || isRemoving || isRequesting
                                                ? Colors.grey.withOpacity(0.1)
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Center(
                                                child: Text(
                                                  '$day-$month-$year (${getDayName(weekday)})',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      ...times.map((time) {
                                        String key = '$day-$month-$year-$time';
                                        return TableCell(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (isRequesting) {
                                                toggleBooking(key);
                                              } else if (isDeactivating) {
                                                toggleActivation(key);
                                              } else if (isRemoving) {
                                                toggleRemoval(key);
                                              }
                                            },
                                            child: Container(
                                              color: selectedSlots.contains(key)
                                                  ? Colors.blue.withOpacity(0.5)
                                                  : authProvider
                                                              .bookings[key] ==
                                                          'Deactivated by Admin'
                                                      ? Colors
                                                          .grey // Deactivated slots
                                                      : authProvider.bookings[
                                                                  key] !=
                                                              null
                                                          ? Colors
                                                              .red // All booked slots are red
                                                          : authProvider.requests[
                                                                      key] !=
                                                                  null
                                                              ? Colors
                                                                  .yellow // All pending requests are yellow
                                                              : Colors
                                                                  .green, // Available slots
                                              height: 50,
                                              child: Center(
                                                child: Text(
                                                  authProvider.bookings[key] ==
                                                          'Deactivated by Admin'
                                                      ? 'Deactivated by Admin'
                                                      : authProvider.bookings[
                                                                  key] !=
                                                              null
                                                          ? authProvider.descriptions[
                                                                          key] !=
                                                                      null &&
                                                                  authProvider
                                                                      .descriptions[
                                                                          key]!
                                                                      .isNotEmpty
                                                              ? '${authProvider.bookings[key]}: ${authProvider.descriptions[key]}'
                                                              : 'Booked by ${authProvider.bookings[key]}'
                                                          : authProvider.requests[
                                                                      key] !=
                                                                  null
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
