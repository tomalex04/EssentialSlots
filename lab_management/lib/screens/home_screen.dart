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
  bool isCancelling = false;
  bool isRemovingBookings = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Initialize bookings map
    for (var date in generateNext10Days()) {
      for (var time in times) {
        authProvider.bookings['$date-$time'] = null;
      }
    }
    
    // Fetch labs and initialize selected lab
    authProvider.fetchLabs().then((_) {
      if (mounted && authProvider.availableLabs.isNotEmpty) {
        setState(() {
          authProvider.selectedLab = authProvider.availableLabs[0];
          authProvider.fetchBookings();
        });
      }
    });
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

    if (isBooking) {
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
    } else if (isCancelling) {
      // For cancelling: only allow selecting slots requested by the current user
      if (authProvider.requests[key] == authProvider.loggedInUser) {
        setState(() {
          if (selectedSlots.contains(key)) {
            selectedSlots.remove(key);
          } else {
            selectedSlots.add(key);
          }
        });
      } else if (authProvider.requests[key] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only cancel your own requests'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void submitBooking() async {
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
      isBooking = false;
      isCancelling = false;
      _descriptionController.clear();
    }); // Reset UI state immediately for all cases
    setState(() {
      isBooking = false;
      isCancelling = false;
      selectedSlots.clear();
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
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void cancelBooking() {
    setState(() {
      selectedSlots.clear();
      isBooking = false;
      _descriptionController.clear();
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
      isBooking = false;
      _descriptionController.clear();
    });
  }

  void startCancelling() {
    setState(() {
      isCancelling = true;
      isBooking = false;
      selectedSlots.clear();
    });
  }

  void cancelSelected() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool allSuccess = true;
    List<String> failedSlots = [];

    // Process each selected slot
    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];

      // Verify the slot is actually requested by the current user
      if (authProvider.requests[slot] != authProvider.loggedInUser) {
        failedSlots.add('$day (Time: $time)');
        continue;
      }

      bool success = await authProvider.cancelRequest(day, time);
      if (!success) {
        allSuccess = false;
        failedSlots.add('$day (Time: $time)');
      }
    }

    // Show appropriate message
    if (allSuccess && selectedSlots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected requests cancelled successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    } else if (failedSlots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to cancel some requests: ${failedSlots.join(", ")}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Reset UI state immediately
    setState(() {
      selectedSlots.clear();
      isCancelling = false;
      isBooking = false; // Ensure we're back in preview mode
      _descriptionController.clear();
    });

    // Refresh data
    await authProvider.fetchBookings();
  }

  void cancelChanges() {
    setState(() {
      selectedSlots.clear();
      isCancelling = false;
    });
  }

  void startRemovingBookings() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      isRemovingBookings = true;
      isBooking = false;
      isCancelling = false;
      selectedSlots.clear();
    });
  }

  void confirmRemoveBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    int successCount = 0;
    List<String> failedSlots = [];
    final selectedSlotsCopy =
        Set<String>.from(selectedSlots); // Make a copy of selected slots

    // Process each selected slot
    for (var slot in selectedSlots) {
      final parts = slot.split('-');
      final day = '${parts[0]}-${parts[1]}-${parts[2]}';
      final time = parts[3];

      // Verify permission
      bool hasPermission = authProvider.userRole == 'admin' ||
          authProvider.bookings[slot] == authProvider.loggedInUser;

      if (!hasPermission) {
        failedSlots.add('$day-$time');
        continue;
      }

      // Attempt removal
      bool success = await authProvider.removeBooking(day, time);
      if (success) {
        successCount++;
      } else {
        failedSlots.add('$day-$time');
      }
    }



    // Show results message
    if (mounted) {
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount booking(s) removed successfully'),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (selectedSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bookings selected for removal'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to remove bookings: ${failedSlots.join(", ")}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Reset state to preview mode
    setState(() {
      selectedSlots.clear();
      isBooking = false;
      isCancelling = false;
      isRemovingBookings = false;
    });

    // Refresh bookings immediately
    await authProvider.fetchBookings();

    // Wait a short moment and refresh again to ensure we have the latest state
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      await authProvider.fetchBookings();
    }
  }

  void cancelRemoveBookings() {
    setState(() {
      selectedSlots.clear();
      isRemovingBookings = false;
    });
  }

  void toggleRow(String date) {
    if (!isBooking && !isCancelling && !isRemovingBookings) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allSlotsInRow = times.map((time) => '$date-$time').toList();
    bool shouldSelect = false;

    // Check if we should select or deselect based on the first available slot
    if (isBooking) {
      // For booking mode, check if any slot in the row can be selected
      shouldSelect = allSlotsInRow.any((key) => 
        !selectedSlots.contains(key) && 
        (authProvider.bookings[key] == null && 
         (authProvider.requests[key] == null || 
          authProvider.requests[key] == authProvider.loggedInUser))
      );
    } else if (isCancelling) {
      // For cancelling mode, check if any slot can be cancelled
      shouldSelect = allSlotsInRow.any((key) =>
        !selectedSlots.contains(key) &&
        authProvider.requests[key] == authProvider.loggedInUser
      );
    } else if (isRemovingBookings) {
      // For removing mode, check if any slot can be removed
      shouldSelect = allSlotsInRow.any((key) =>
        !selectedSlots.contains(key) &&
        (authProvider.userRole == 'admin' || 
         authProvider.bookings[key] == authProvider.loggedInUser)
      );
    }

    setState(() {
      for (String key in allSlotsInRow) {
        if (shouldSelect) {
          // Add slots based on the current mode
          if (isBooking) {
            if (authProvider.bookings[key] == null &&
                (authProvider.requests[key] == null ||
                 authProvider.requests[key] == authProvider.loggedInUser)) {
              selectedSlots.add(key);
            }
          } else if (isCancelling) {
            if (authProvider.requests[key] == authProvider.loggedInUser) {
              selectedSlots.add(key);
            }
          } else if (isRemovingBookings) {
            if (authProvider.userRole == 'admin' ||
                authProvider.bookings[key] == authProvider.loggedInUser) {
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
                title: const Text('Home'),
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
                      title: const Text('Request/Cancel Slots'),
                      onTap: () {
                        setState(() {
                          isBooking = true;
                          selectedSlots.clear();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      title: const Text('Remove Bookings'),
                      onTap: () {
                        setState(() {
                          isRemovingBookings = true;
                          selectedSlots.clear();
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
                      value: authProvider.selectedLab ?? (authProvider.availableLabs.isNotEmpty ? authProvider.availableLabs[0] : null),
                      hint: const Text('Select Lab'),
                      isExpanded: true,
                      items: authProvider.availableLabs.map((String lab) {
                        return DropdownMenuItem<String>(
                          value: lab,
                          child: Text(lab),
                        );
                      }).toList(),
                      onChanged: authProvider.availableLabs.isEmpty ? null : (String? newValue) async {
                        if (newValue != null) {
                          // Update the provider
                          setState(() {
                            Provider.of<AuthProvider>(context, listen: false).selectedLab = newValue;
                          });
                          
                          // Small delay to ensure state is updated
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          if (mounted) {
                            // Show loading indicator
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Loading bookings for $newValue...'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            
                            // Fetch the bookings
                            await Provider.of<AuthProvider>(context, listen: false).fetchBookings();
                          }
                        }
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
                                    onPressed: submitBooking,
                                    child: const Text('Submit Changes'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: cancelBooking,
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ],
                            if (isCancelling) ...[
                              const Text('Cancelling Requests',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              const Text('Selected slots will be cancelled.'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: cancelSelected,
                                    child: const Text('Confirm Cancellation'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: cancelChanges,
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ],
                            if (isRemovingBookings) ...[
                              const Text('Remove Bookings',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              const Text('Select your bookings to remove'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: confirmRemoveBookings,
                                    child: const Text('Confirm Removal'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: cancelRemoveBookings,
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ],
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
                                                  child: Center(child: Text(''))),
                                              ...List.generate(
                                                  6,
                                                  (index) => TableCell(
                                                        child: Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                  'Hour ${times[index]}'),
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
                                                  child: GestureDetector(
                                                    onTap: () => toggleRow('$day-$month-$year'),
                                                    child: Container(
                                                      color: isBooking || isCancelling || isRemovingBookings
                                                          ? Colors.grey.withOpacity(0.1)
                                                          : null,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text('$day-$month-$year'),
                                                            Text(getDayName(weekday)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                ...times.map((time) {
                                                  String key =
                                                      '$day-$month-$year-$time';
                                                  return TableCell(
                                                    child: GestureDetector(
                                                        onTap: () {
                                                          if (isBooking) {
                                                            toggleBooking(key);
                                                          } else if (isRemovingBookings) {
                                                            // Allow admins to select any booking, but users can only select their own
                                                            final authProvider =
                                                                Provider.of<
                                                                        AuthProvider>(
                                                                    context,
                                                                    listen: false);
                                                            if (authProvider
                                                                        .userRole ==
                                                                    'admin' ||
                                                                authProvider.bookings[
                                                                        key] ==
                                                                    authProvider
                                                                        .loggedInUser) {
                                                              setState(() {
                                                                if (selectedSlots
                                                                    .contains(key)) {
                                                                  selectedSlots
                                                                      .remove(key);
                                                                } else {
                                                                  selectedSlots
                                                                      .add(key);
                                                                }
                                                              });
                                                            } else if (authProvider
                                                                    .bookings[key] !=
                                                                null) {
                                                              ScaffoldMessenger.of(
                                                                      context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                      'You can only remove your own bookings'),
                                                                  duration: Duration(
                                                                      seconds: 2),
                                                                ),
                                                              );
                                                            }
                                                          } else if (isCancelling) {
                                                            toggleBooking(key);
                                                          }
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                          color: selectedSlots
                                                                  .contains(key)
                                                              ? (isRemovingBookings
                                                                  ? Colors.red
                                                                      .withOpacity(
                                                                          0.3) // Selected for removal
                                                                  : authProvider.requests[
                                                                              key] ==
                                                                          authProvider
                                                                              .loggedInUser
                                                                      ? Colors.orange
                                                                          .withOpacity(
                                                                              0.5) // Selected for cancellation
                                                                      : Colors.blue
                                                                          .withOpacity(
                                                                              0.5)) // Selected for request
                                                              : authProvider.bookings[
                                                                          key] ==
                                                                      'Deactivated by Admin'
                                                                  ? Colors.grey
                                                                  : authProvider.bookings[
                                                                              key] !=
                                                                          null
                                                                      ? Colors
                                                                          .red // All bookings same color
                                                                      : authProvider.requests[
                                                                                  key] !=
                                                                              null
                                                                          ? Colors
                                                                              .yellow
                                                                          : Colors
                                                                              .green, // Available slots
                                                          height: 50,
                                                          child: Center(
                                                            child: Text(
                                                              authProvider.bookings[
                                                                          key] ==
                                                                      'Deactivated by Admin'
                                                                  ? 'Deactivated'
                                                                  : authProvider.bookings[
                                                                              key] !=
                                                                          null
                                                                      ? authProvider.descriptions[key] !=
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
                                                                          ? 'Requested by ${authProvider.requests[key]}'
                                                                          : 'Available',
                                                              textAlign:
                                                                  TextAlign.center,
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
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ), // Close Expanded
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
