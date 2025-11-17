import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../layouts/dashboard_layout.dart';

class ManagerProfileScreen extends StatefulWidget {
  const ManagerProfileScreen({super.key});

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _officeAddressController = TextEditingController();
  final _dobController = TextEditingController();
  final _dateJoinedController = TextEditingController();
  final _ageController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _managerLevelController = TextEditingController();
  final _projectsHandledController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _profilePicture = '';
  File? _selectedImage;
  String _message = '';
  bool _isError = false;

  // Extra profile state
  List<String> _departments = [];
  String _department = '';
  bool _ageManual = false;

  @override
  void initState() {
    super.initState();
    _fetchManagerProfile();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeAddressController.dispose();
    _dobController.dispose();
    _dateJoinedController.dispose();
    _ageController.dispose();
    _teamSizeController.dispose();
    _managerLevelController.dispose();
    _projectsHandledController.dispose();
    super.dispose();
  }

  Future<void> _fetchManagerProfile() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email') ?? '';

      if (userEmail.isEmpty) {
        throw Exception('No logged-in email found');
      }

      final response = await _apiService.get('/accounts/managers/${Uri.encodeComponent(userEmail)}/');

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _fullnameController.text = data['fullname']?.toString() ?? '';
          _emailController.text = data['email']?.toString() ?? userEmail;
          _phoneController.text = data['phone']?.toString() ?? '';
          _officeAddressController.text = data['office_address']?.toString() ?? '';
          _profilePicture = data['profile_picture']?.toString() ?? '';

          _department = data['department']?.toString() ?? '';
          _dobController.text = data['date_of_birth']?.toString() ?? '';
          _dateJoinedController.text = data['date_joined']?.toString() ?? '';

          final apiAge = data['age'];
          if (apiAge != null && apiAge.toString().isNotEmpty) {
            _ageController.text = apiAge.toString();
          } else {
            final calculated = _calculateAge(_dobController.text);
            _ageController.text = calculated?.toString() ?? '';
          }

          _teamSizeController.text =
              data['team_size'] != null ? data['team_size'].toString() : '';
          _managerLevelController.text =
              data['manager_level'] != null ? data['manager_level'].toString() : '';
          _projectsHandledController.text = data['projects_handled'] != null
              ? data['projects_handled'].toString()
              : '';

          _ageManual = false;

          _message = '';
          _isError = false;
        });
      } else {
        throw Exception('Failed to fetch manager details');
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to load manager profile: $e';
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await _apiService.get('/accounts/departments/');
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          setState(() {
            _departments = data
                .map((e) => (e['department_name'] ?? '').toString())
                .where((name) => name.isNotEmpty)
                .cast<String>()
                .toList();
          });
        }
      }
    } catch (_) {
      // Ignore department load errors for now
    }
  }

  int? _calculateAge(String dob) {
    if (dob.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  String _calculateVintage(String dateJoined) {
    if (dateJoined.isEmpty) return 'N/A';
    try {
      final joinedDate = DateTime.parse(dateJoined);
      final now = DateTime.now();

      if (now.isBefore(joinedDate)) return 'N/A';

      int years = now.year - joinedDate.year;
      int months = now.month - joinedDate.month;
      int days = now.day - joinedDate.day;

      if (days < 0) {
        months--;
        final prevMonth = DateTime(now.year, now.month, 0);
        days += prevMonth.day;
      }

      if (months < 0) {
        years--;
        months += 12;
      }

      if (years < 0) return 'N/A';

      return '$years year${years == 1 ? '' : 's'}, '
          '$months month${months == 1 ? '' : 's'}, '
          '$days day${days == 1 ? '' : 's'}';
    } catch (_) {
      return 'N/A';
    }
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required String label,
    void Function(DateTime)? onDateSelected,
  }) async {
    final initial = controller.text.isNotEmpty
        ? DateTime.tryParse(controller.text) ?? DateTime.now()
        : DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      final formatted =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formatted;
      });
      if (onDateSelected != null) {
        onDateSelected(date);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Basic phone validation like web version
    if (_phoneController.text.isNotEmpty) {
      final phoneRegex = RegExp(r'^[\+]?[0-9]{6,15}$');
      if (!phoneRegex
          .hasMatch(_phoneController.text.replaceAll(RegExp(r'\s+'), ''))) {
        setState(() {
          _message = 'Please enter a valid phone number';
          _isError = true;
        });
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/accounts/managers/${Uri.encodeComponent(_emailController.text)}/',
      );
      final request = http.MultipartRequest('PATCH', uri);

      // Headers
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Fields (match web fields)
      request.fields['fullname'] = _fullnameController.text;
      request.fields['phone'] = _phoneController.text;
      request.fields['office_address'] = _officeAddressController.text;
      request.fields['department'] = _department;
      request.fields['date_of_birth'] = _dobController.text;
      request.fields['date_joined'] = _dateJoinedController.text;

      if (_ageController.text.trim().isNotEmpty) {
        request.fields['age'] = _ageController.text.trim();
      }
      if (_teamSizeController.text.trim().isNotEmpty) {
        request.fields['team_size'] = _teamSizeController.text.trim();
      }
      if (_managerLevelController.text.trim().isNotEmpty) {
        request.fields['manager_level'] = _managerLevelController.text.trim();
      }
      if (_projectsHandledController.text.trim().isNotEmpty) {
        request.fields['projects_handled'] =
            _projectsHandledController.text.trim();
      }

      // Image
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            _selectedImage!.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updated = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _profilePicture =
              updated['profile_picture']?.toString() ?? _profilePicture;
          _isEditing = false;
          _selectedImage = null;
          _message = 'Profile updated successfully!';
          _isError = false;
        });

        // Optionally refresh calculated age/vintage from server
        _fetchManagerProfile();
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to save changes: $e';
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _message = '';
    });
    _fetchManagerProfile();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'manager',
      child: Container(
        color: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'Manager Profile',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_message.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _isError
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isError
                                      ? Colors.red.shade200
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                _message,
                                style: TextStyle(
                                  color: _isError
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          _buildProfileImage(),
                          const SizedBox(height: 32),

                          _buildTextField(
                            controller: _fullnameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email,
                            enabled: false,
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            icon: Icons.phone,
                            hintText: 'Enter phone number',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _officeAddressController,
                            label: 'Office Address',
                            icon: Icons.location_on,
                            hintText: 'Enter office address',
                          ),
                          const SizedBox(height: 20),

                          // Department
                          _buildDepartmentDropdown(),
                          const SizedBox(height: 20),

                          // Date of Birth & Age
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  controller: _dobController,
                                  label: 'Date of Birth',
                                  onDateSelected: (_) {
                                    if (!_ageManual) {
                                      final age =
                                          _calculateAge(_dobController.text);
                                      setState(() {
                                        _ageController.text =
                                            age?.toString() ?? '';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _ageController,
                                  label: 'Age',
                                  icon: Icons.calendar_today,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    _ageManual = true;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Date Joined & Vintage
                          _buildDateField(
                            controller: _dateJoinedController,
                            label: 'Date Joined',
                          ),
                          const SizedBox(height: 12),
                          _buildVintageField(),
                          const SizedBox(height: 20),

                          // Team Size
                          _buildTextField(
                            controller: _teamSizeController,
                            label: 'Team Size',
                            icon: Icons.group,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 20),

                          // Manager Level
                          _buildTextField(
                            controller: _managerLevelController,
                            label: 'Manager Level',
                            icon: Icons.leaderboard,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 20),

                          // Projects Handled
                          _buildTextField(
                            controller: _projectsHandledController,
                            label: 'Projects Handled',
                            icon: Icons.work_outline,
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 32),

                          if (!_isEditing)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _isEditing = true),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _cancelEdit,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _saveProfile,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.save),
                                    label: Text(
                                      _isSaving ? 'Saving...' : 'Save Changes',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.shade500, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : _profilePicture.isNotEmpty
                    ? Image.network(
                        _profilePicture,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 60, color: Colors.grey),
                      )
                    : const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey,
                      ),
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled && _isEditing,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: true,
            fillColor:
                (enabled && _isEditing) ? Colors.white : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business_center,
                size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            const Text(
              'Department',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _department.isNotEmpty && _departments.contains(_department)
              ? _department
              : null,
          items: _departments
              .map(
                (dept) => DropdownMenuItem<String>(
                  value: dept,
                  child: Text(dept),
                ),
              )
              .toList(),
          onChanged: _isEditing
              ? (value) {
                  setState(() {
                    _department = value ?? '';
                  });
                }
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    void Function(DateTime)? onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: _isEditing
              ? () => _pickDate(
                    controller: controller,
                    label: label,
                    onDateSelected: onDateSelected,
                  )
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildVintageField() {
    final vintage = _calculateVintage(_dateJoinedController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vintage',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            vintage,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
