import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/shift_model.dart';
import '../models/employee_profile_model.dart';
import '../services/shift_service.dart';
import '../services/profile_service.dart';

class ShiftMakerWidget extends StatefulWidget {
  const ShiftMakerWidget({super.key});

  @override
  State<ShiftMakerWidget> createState() => _ShiftMakerWidgetState();
}

class _ShiftMakerWidgetState extends State<ShiftMakerWidget>
    with SingleTickerProviderStateMixin {
  final ShiftService _shiftService = ShiftService();

  late TabController _tabController;

  // Data
  List<Employee> employees = [];
  List<Shift> shifts = [];
  List<OvertimeRecord> overtimeRecords = [];
  List<Manager> managers = [];
  List<ShiftColumn> shiftColumns = [];

  // State
  bool isLoading = true;
  String error = '';
  String selectedDate = DateTime.now().toIso8601String().split('T')[0];
  bool hasUnsavedChanges = false;
  bool isSaving = false;
  bool isViewMode = true; // Start in view mode
  String? managerEmail;

  // Local state for drag and drop (track current assignments)
  Map<String, String> currentAssignments = {}; // employee_email -> shift_type
  Employee? draggedEmployee; // For drag operations
  Employee? selectedEmployee; // For mobile selection
  bool hasLocalChanges = false; // Track if we have unsaved local changes

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // Get manager email
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_info');
      if (userInfoString != null) {
        final userInfo = jsonDecode(userInfoString);
        managerEmail = userInfo['email'];
      }

      // Fetch managers list
      final profileService = ProfileService();
      final fetchedManagers = await profileService.fetchManagers();
      setState(() => managers = fetchedManagers);

      // Initialize shift columns
      shiftColumns = [
        ShiftColumn(
          id: 'Morning',
          title: 'Morning Shift',
          timeRange: '9:00 AM - 5:00 PM',
          employees: [],
        ),
        ShiftColumn(
          id: 'Evening',
          title: 'Evening Shift',
          timeRange: '2:00 PM - 10:00 PM',
          employees: [],
        ),
        ShiftColumn(
          id: 'Night',
          title: 'Night Shift',
          timeRange: '10:00 PM - 6:00 AM',
          employees: [],
        ),
      ];

      await _fetchAllData();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    try {
      // Fetch employees
      final fetchedEmployees = await _shiftService.fetchEmployees();

      // Fetch shifts and OT for selected date
      final fetchedShifts = await _shiftService.fetchShifts(selectedDate);
      final fetchedOT = await _shiftService.fetchOvertimeRecords(selectedDate);

      setState(() {
        employees = fetchedEmployees;
        shifts = fetchedShifts;
        overtimeRecords = fetchedOT;
        error = '';
      });

      // Initialize current assignments from database data
      _initializeCurrentAssignments();

      // Update shift columns with current data
      _updateShiftColumns();

      // Auto-enter edit mode if no shifts exist (creation mode)
      final hasExistingShifts = currentAssignments.isNotEmpty;
      setState(() => isViewMode = hasExistingShifts);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateShiftColumns() {
    setState(() {
      shiftColumns = shiftColumns.map((column) {
        // Get employees assigned to this shift (from current assignments)
        final assignedEmails = currentAssignments.entries
            .where((entry) => entry.value == column.id)
            .map((entry) => entry.key)
            .toSet();

        final columnEmployees = assignedEmails
            .map(
              (email) => employees.firstWhere(
                (emp) => emp.email == email,
                orElse: () => Employee(email: email, fullname: 'Unknown'),
              ),
            )
            .toList();

        return column.copyWith(employees: columnEmployees);
      }).toList();
    });
  }

  // Initialize current assignments from shifts data
  void _initializeCurrentAssignments() {
    currentAssignments.clear();
    for (final shift in shifts) {
      if (shift.status == 'active' && shift.date == selectedDate) {
        currentAssignments[shift.employeeEmail] = shift.shiftType;
      }
    }
  }

  List<Employee> get _unassignedEmployees {
    final assignedEmails = shifts
        .where(
          (shift) => shift.status == 'active' && shift.date == selectedDate,
        )
        .map((shift) => shift.employeeEmail)
        .toSet();

    return employees
        .where((emp) => !assignedEmails.contains(emp.email))
        .toList();
  }

  int get _totalAssignedEmployees {
    return shifts
        .where((shift) => shift.status == 'active')
        .map((shift) => shift.employeeEmail)
        .toSet()
        .length;
  }

  bool get _isToday {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return selectedDate == today;
  }

  bool get _isPastDate {
    final selected = DateTime.parse(selectedDate);
    final today = DateTime.now();
    return selected.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get _isFutureDate {
    final selected = DateTime.parse(selectedDate);
    final today = DateTime.now();
    return selected.isAfter(DateTime(today.year, today.month, today.day));
  }

  Future<void> _handleSaveAllShifts() async {
    if (!_isToday && !_isFutureDate) return;

    setState(() => isSaving = true);
    try {
      // First, delete all existing shifts for this date
      final existingShifts = shifts
          .where(
            (shift) => shift.date == selectedDate && shift.status == 'active',
          )
          .toList();

      if (existingShifts.isNotEmpty) {
        final shiftIds = existingShifts
            .map((s) => s.id)
            .where((id) => id != null)
            .cast<int>()
            .toList();
        if (shiftIds.isNotEmpty) {
          await _shiftService.bulkDeleteShifts(shiftIds);
        }
      }

      // Create new shifts based on current assignments
      if (currentAssignments.isNotEmpty) {
        final shiftsData = currentAssignments.entries.map((entry) {
          // Determine start and end times based on shift type
          String startTime, endTime;
          switch (entry.value) {
            case 'Morning':
              startTime = '09:00';
              endTime = '17:00';
              break;
            case 'Evening':
              startTime = '14:00';
              endTime = '22:00';
              break;
            case 'Night':
              startTime = '22:00';
              endTime = '06:00';
              break;
            default:
              startTime = '09:00';
              endTime = '17:00';
          }

          return {
            'date': selectedDate,
            'start_time': startTime,
            'end_time': endTime,
            'emp_email': entry.key,
            'manager_email':
                managerEmail ?? 'manager@globaltechsoftwaresolutions.com',
            'shift': entry.value,
          };
        }).toList();

        await _shiftService.bulkCreateShifts(shiftsData);
      }

      setState(() {
        hasUnsavedChanges = false;
        hasLocalChanges = false;
        isViewMode = true;
      });

      // Refresh data
      await _fetchAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All shifts saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shifts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  // Move employee to shift (local state update)
  void _moveEmployeeToShift(String targetShiftId, String employeeEmail) {
    setState(() {
      // Remove from any existing assignment
      currentAssignments.remove(employeeEmail);

      // Add to new assignment
      currentAssignments[employeeEmail] = targetShiftId;

      // Mark as having changes
      hasLocalChanges = true;
      hasUnsavedChanges = true;

      // Update UI
      _updateShiftColumns();
    });

    // Clear mobile selection
    selectedEmployee = null;

    // Show feedback
    final employee = employees.firstWhere((emp) => emp.email == employeeEmail);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${employee.displayName} to $targetShiftId shift',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Remove employee from shift (local state update)
  void _removeEmployeeFromShift(String employeeEmail) {
    setState(() {
      currentAssignments.remove(employeeEmail);
      hasLocalChanges = true;
      hasUnsavedChanges = true;
      _updateShiftColumns();
    });

    final employee = employees.firstWhere((emp) => emp.email == employeeEmail);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${employee.displayName} from shift')),
      );
    }
  }

  // Handle drag start
  void _handleDragStart(Employee employee) {
    setState(() => draggedEmployee = employee);
  }

  // Handle drag end
  void _handleDragEnd() {
    setState(() => draggedEmployee = null);
  }

  // Handle drop on shift column
  void _handleDropOnColumn(String targetShiftId) {
    if (draggedEmployee != null) {
      _moveEmployeeToShift(targetShiftId, draggedEmployee!.email);
      setState(() => draggedEmployee = null);
    }
  }

  // Handle long press start (for mobile)
  void _handleLongPressStart(Employee employee) {
    setState(() => draggedEmployee = employee);
    // Provide haptic feedback if available
    // HapticFeedback.selectionClick();
  }

  // Handle long press end (for mobile)
  void _handleLongPressEnd() {
    setState(() => draggedEmployee = null);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAllData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 18),
                    SizedBox(width: 8),
                    Text('Shifts'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Overtime'),
                  ],
                ),
              ),
            ],
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Shifts Tab
              _buildShiftsTab(),

              // Overtime Tab
              _buildOvertimeTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.blue.shade50],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions and Selected Employee Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isMobile()
                              ? "Tap employees and then tap shift columns to move them"
                              : "Drag and drop employees to assign shifts",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        if (selectedEmployee != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              'Selected: ${selectedEmployee!.displayName}',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Date Picker
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          initialValue: selectedDate,
                          decoration: const InputDecoration(
                            labelText: 'Select Date',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          readOnly: true,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.parse(selectedDate),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(
                                () => selectedDate = picked
                                    .toIso8601String()
                                    .split('T')[0],
                              );
                              _fetchAllData();
                            }
                          },
                        ),
                      ),

                      // Status indicator
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isPastDate
                              ? Colors.grey.shade100
                              : _isFutureDate
                              ? Colors.blue.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isPastDate
                              ? 'Past Date - View Only'
                              : _isFutureDate
                              ? 'Future Date - Planning'
                              : 'Today - Editable',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isPastDate
                                ? Colors.grey.shade700
                                : _isFutureDate
                                ? Colors.blue.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Save Button (only show when there are unsaved changes and it's today/future)
              if (hasUnsavedChanges && (_isToday || _isFutureDate)) ...[
                Center(
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _handleSaveAllShifts,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      isSaving
                          ? 'Saving All Shifts...'
                          : 'Save All Shifts (${_totalAssignedEmployees} employees)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Edit/View Mode Toggle
              if (_totalAssignedEmployees > 0 && !_isPastDate) ...[
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => isViewMode = !isViewMode),
                    icon: Icon(isViewMode ? Icons.edit : Icons.visibility),
                    label: Text(isViewMode ? 'Edit Shifts' : 'View Mode'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Shift Columns
              ...shiftColumns.map(
                (column) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildShiftColumn(column),
                ),
              ),

              // Unassigned Employees
              if (_unassignedEmployees.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildUnassignedEmployees(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftColumn(ShiftColumn column) {
    final isInteractive = !_isPastDate && !isViewMode;
    final isMobile = _isMobile();

    return DragTarget<Employee>(
      onWillAccept: (employee) => isInteractive && employee != null,
      onAccept: (employee) => _handleDropOnColumn(column.id),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidateData.isNotEmpty && isInteractive
                  ? Colors.blue.shade400
                  : selectedEmployee != null && isInteractive
                  ? Colors.blue.shade300
                  : Colors.grey.shade200,
              width: candidateData.isNotEmpty && isInteractive ? 3 : 1,
            ),
            boxShadow: candidateData.isNotEmpty && isInteractive
                ? [BoxShadow(color: Colors.blue.shade100, blurRadius: 8)]
                : null,
          ),
          child: Column(
            children: [
              // Column Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: column.id == 'Morning'
                      ? Colors.green.shade50
                      : column.id == 'Evening'
                      ? Colors.blue.shade50
                      : Colors.purple.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: column.id == 'Morning'
                                ? Colors.green.shade100
                                : column.id == 'Evening'
                                ? Colors.blue.shade100
                                : Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            column.id == 'Morning'
                                ? Icons.wb_sunny
                                : column.id == 'Evening'
                                ? Icons.wb_twilight
                                : Icons.nights_stay,
                            color: column.id == 'Morning'
                                ? Colors.green.shade700
                                : column.id == 'Evening'
                                ? Colors.blue.shade700
                                : Colors.purple.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                column.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                column.timeRange,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '${column.employees.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Move Here Button (only show on mobile when employee is selected)
                    if (isInteractive &&
                        isMobile &&
                        selectedEmployee != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _moveEmployeeToShift(
                            column.id,
                            selectedEmployee!.email,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Move Here'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: column.id == 'Morning'
                                ? Colors.green.shade600
                                : column.id == 'Evening'
                                ? Colors.blue.shade600
                                : Colors.purple.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Employees List
              Container(
                constraints: const BoxConstraints(minHeight: 200),
                padding: const EdgeInsets.all(16),
                child: column.employees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              candidateData.isNotEmpty && isInteractive
                                  ? Icons.add_circle
                                  : Icons.people_outline,
                              size: 32,
                              color: candidateData.isNotEmpty && isInteractive
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isInteractive
                                  ? (isMobile && selectedEmployee != null
                                        ? 'Tap "Move Here" to assign employee'
                                        : candidateData.isNotEmpty
                                        ? 'Release to drop employee here'
                                        : 'Drop employees here or tap to select')
                                  : 'No employees assigned',
                              style: TextStyle(
                                color: candidateData.isNotEmpty && isInteractive
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade500,
                                fontSize: 14,
                                fontWeight:
                                    candidateData.isNotEmpty && isInteractive
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isInteractive &&
                                isMobile &&
                                selectedEmployee == null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'First tap an employee below to select them',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: column.employees
                            .map(
                              (employee) => _buildEmployeeCard(
                                employee,
                                column.id,
                                isInteractive,
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeCard(
    Employee employee,
    String shiftId,
    bool isInteractive,
  ) {
    final isMobile = _isMobile();
    final isSelected = selectedEmployee?.email == employee.email;
    final isDragged = draggedEmployee?.email == employee.email;

    // Create the card content
    Widget cardContent = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDragged
            ? Colors.blue.shade100
            : isSelected
            ? Colors.orange.shade100
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragged
              ? Colors.blue.shade400
              : isSelected
              ? Colors.orange.shade300
              : Colors.grey.shade200,
          width: isDragged || isSelected ? 2 : 1,
        ),
        boxShadow: isDragged
            ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 4)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle (desktop only)
          if (isInteractive && !isMobile && shiftId.isEmpty) ...[
            Icon(Icons.drag_indicator, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 4),
          ],

          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: employee.profilePicture != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      employee.profilePicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: Text(employee.initials)),
                    ),
                  )
                : Center(
                    child: Text(
                      employee.initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 8),

          // Name
          Text(
            employee.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDragged
                  ? Colors.blue.shade800
                  : isSelected
                  ? Colors.orange.shade800
                  : null,
            ),
          ),

          // Selection indicator
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, size: 16, color: Colors.orange.shade600),
          ],

          // Remove button (only for assigned employees in edit mode)
          if (isInteractive && shiftId.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeEmployeeFromShift(employee.email),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.close, size: 12, color: Colors.red.shade600),
              ),
            ),
          ],
        ],
      ),
    );

    // Wrap with Draggable for desktop
    if (isInteractive && !isMobile && shiftId.isEmpty) {
      return Draggable<Employee>(
        data: employee,
        onDragStarted: () => _handleDragStart(employee),
        onDragEnd: (_) => _handleDragEnd(),
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: cardContent,
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: cardContent),
        child: cardContent,
      );
    }

    // For mobile or non-interactive, just return the card with tap functionality
    return GestureDetector(
      onTap: isInteractive && isMobile && shiftId.isEmpty
          ? () => setState(() => selectedEmployee = employee)
          : null,
      onLongPressStart: isInteractive && isMobile && shiftId.isEmpty
          ? (_) => _handleLongPressStart(employee)
          : null,
      onLongPressEnd: isInteractive && isMobile && shiftId.isEmpty
          ? (_) => _handleLongPressEnd()
          : null,
      child: cardContent,
    );
  }

  Widget _buildUnassignedEmployees() {
    final isInteractive = !_isPastDate && !isViewMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unassigned Employees',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unassignedEmployees
                .map(
                  (employee) => _buildEmployeeCard(employee, '', isInteractive),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.green.shade50],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Date Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overtime Records',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      initialValue: selectedDate,
                      decoration: const InputDecoration(
                        labelText: 'Select Date',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.parse(selectedDate),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(
                            () => selectedDate = picked.toIso8601String().split(
                              'T',
                            )[0],
                          );
                          _fetchAllData();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add OT Button
              if (!_isPastDate) ...[
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _showAddOvertimeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Overtime Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Overtime Records List
              if (overtimeRecords.isEmpty) ...[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No overtime records found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'for ${DateFormat('MMM dd, yyyy').format(DateTime.parse(selectedDate))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...overtimeRecords.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildOvertimeCard(record),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOvertimeCard(OvertimeRecord record) {
    final employee = employees.firstWhere(
      (emp) => emp.email == record.employeeEmail,
      orElse: () => Employee(
        email: record.employeeEmail,
        fullname: record.empName ?? 'Unknown Employee',
      ),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info
            Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: employee.profilePicture != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            employee.profilePicture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(child: Text(employee.initials)),
                          ),
                        )
                      : Center(
                          child: Text(
                            employee.initials,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Employee Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        employee.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // OT Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Hours (calculate on frontend)
                  Builder(
                    builder: (context) {
                      double calculatedHours = 0;
                      int calculatedMinutes = 0;

                      if (record.otStart != null && record.otEnd != null) {
                        try {
                          final startTime = DateTime.parse(record.otStart!);
                          final endTime = DateTime.parse(record.otEnd!);
                          final difference = endTime.difference(startTime);
                          calculatedMinutes = difference.inMinutes;
                          calculatedHours = calculatedMinutes / 60.0;
                        } catch (e) {
                          // Fallback to API value if parsing fails
                          calculatedHours = record.hours;
                          calculatedMinutes = (record.hours * 60).round();
                        }
                      } else {
                        // Fallback to API value if times are null
                        calculatedHours = record.hours;
                        calculatedMinutes = (record.hours * 60).round();
                      }

                      return Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${calculatedHours.toStringAsFixed(2)} hours (${calculatedMinutes} minutes)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (record.otStart != null && record.otEnd != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatTime(record.otStart!)} - ${_formatTime(record.otEnd!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Approved Info
                  if (record.approvedBy != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Approved by: ${record.approvedBy}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOvertimeDialog() {
    String? selectedEmployeeEmail;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Overtime Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Employee Dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Employee',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedEmployeeEmail,
                  items: employees.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee.email,
                      child: Text(employee.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedEmployeeEmail = value);
                  },
                ),

                const SizedBox(height: 16),

                // Start Time
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => startTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      startTime != null
                          ? startTime!.format(context)
                          : 'Select start time',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // End Time
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => endTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      endTime != null
                          ? endTime!.format(context)
                          : 'Select end time',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selectedEmployeeEmail != null &&
                      startTime != null &&
                      endTime != null
                  ? () {
                      _createOvertimeRecord(
                        selectedEmployeeEmail!,
                        startTime!,
                        endTime!,
                      );
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOvertimeRecord(
    String employeeEmail,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    try {
      final otStart = DateTime(
        DateTime.parse(selectedDate).year,
        DateTime.parse(selectedDate).month,
        DateTime.parse(selectedDate).day,
        startTime.hour,
        startTime.minute,
      ).toIso8601String();

      final otEnd = DateTime(
        DateTime.parse(selectedDate).year,
        DateTime.parse(selectedDate).month,
        DateTime.parse(selectedDate).day,
        endTime.hour,
        endTime.minute,
      ).toIso8601String();

      // Use the first available manager, or fallback to default
      final validManagerEmail = managers.isNotEmpty
          ? managers.first.email
          : 'manager@globaltechsoftwaresolutions.com';

      await _shiftService.createOvertimeRecord(
        employeeEmail: employeeEmail,
        managerEmail: validManagerEmail,
        otStart: otStart,
        otEnd: otEnd,
      );

      // Refresh data
      await _fetchAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Overtime record added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding overtime record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return isoString;
    }
  }

  bool _isMobile() {
    return MediaQuery.of(context).size.width < 768;
  }
}
