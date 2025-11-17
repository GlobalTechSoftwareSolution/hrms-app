import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class HrProfileScreen extends StatefulWidget {
  const HrProfileScreen({super.key});

  @override
  State<HrProfileScreen> createState() => _HrProfileScreenState();
}

class _HrProfileScreenState extends State<HrProfileScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _dobController = TextEditingController();
  final _ageController = TextEditingController();
  final _dateJoinedController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _skillsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _ageManual = false;

  String _profilePicture = '';
  File? _selectedImage;

  List<String> _departments = [];
  String _message = '';
  String _messageType = ''; // 'success' | 'error'

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchDepartments(),
        _fetchProfile(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _dateJoinedController.dispose();
    _qualificationController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartments() async {
    try {
      final res = await _apiService.get('/accounts/departments/');
      if (res['success'] == true) {
        final data = res['data'];
        if (data is List) {
          setState(() {
            _departments = data
                .map((e) => (e['department_name'] ?? '').toString())
                .where((v) => v.isNotEmpty)
                .cast<String>()
                .toList();
          });
        }
      }
    } catch (_) {
      // ignore; department list is optional
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoStr = prefs.getString('user_info');
      if (userInfoStr == null) {
        throw Exception('No user info found');
      }
      final userInfo = jsonDecode(userInfoStr) as Map<String, dynamic>;
      final email = (userInfo['email'] ?? '').toString();
      if (email.isEmpty) {
        throw Exception('No email in user info');
      }

      final res = await _apiService.get('/accounts/hrs/${Uri.encodeComponent(email)}/');

      Map<String, dynamic>? data;
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(res['data']);
      } else if (res is Map && res['email'] != null) {
        data = Map<String, dynamic>.from(res);
      }

      if (data == null) {
        throw Exception('Invalid HR profile response');
      }

      final fullname = data['fullname']?.toString() ?? '';
      final phone = data['phone']?.toString() ?? '';
      final department = data['department']?.toString() ?? '';
      final dob = data['date_of_birth']?.toString() ?? '';
      final dateJoined = data['date_joined']?.toString() ?? '';
      final qualification =
          (data['qualification'] ?? '').toString();
      final skills = (data['skills'] ?? '').toString();

      String profilePic = data['profile_picture']?.toString() ?? '';
      if (profilePic.isNotEmpty && !profilePic.startsWith('http')) {
        profilePic = '${ApiService.baseUrl}/$profilePic';
      }

      final ageField = data['age'];
      final int? calculatedAge = dob.isNotEmpty ? _calculateAge(dob) : null;
      final int? apiAge = ageField == null
          ? null
          : int.tryParse(ageField.toString());

      setState(() {
        _nameController.text = fullname;
        _emailController.text = email;
        _phoneController.text = phone;
        _departmentController.text = department;
        _dobController.text = dob.isNotEmpty ? dob.split('T').first : '';
        _dateJoinedController.text =
            dateJoined.isNotEmpty ? dateJoined.split('T').first : '';
        _qualificationController.text = qualification;
        _skillsController.text = skills;
        _profilePicture = profilePic;
        _ageController.text = (apiAge ?? calculatedAge)?.toString() ?? '';
        _ageManual = apiAge != null;
        _message = '';
        _messageType = '';
      });
    } catch (e) {
      setState(() {
        _message = 'Failed to load profile: $e';
        _messageType = 'error';
      });
    }
  }

  int? _calculateAge(String dob) {
    try {
      final date = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - date.year;
      if (today.month < date.month ||
          (today.month == date.month && today.day < date.day)) {
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
      final joined = DateTime.parse(dateJoined);
      final today = DateTime.now();

      if (today.isBefore(joined)) return '0 years, 0 months, 0 days';

      int years = today.year - joined.year;
      int months = today.month - joined.month;
      int days = today.day - joined.day;

      if (days < 0) {
        months--;
        final prevMonth = DateTime(today.year, today.month, 0);
        days += prevMonth.day;
      }
      if (months < 0) {
        years--;
        months += 12;
      }

      if (years < 0) {
        years = 0;
        months = 0;
        days = 0;
      }

      String yearStr = years == 1 ? '1 year' : '$years years';
      String monthStr = months == 1 ? '1 month' : '$months months';
      String dayStr = days == 1 ? '1 day' : '$days days';
      return '$yearStr, $monthStr, $dayStr';
    } catch (_) {
      return 'N/A';
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
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
      final formatted = DateFormat('yyyy-MM-dd').format(date);
      setState(() {
        controller.text = formatted;
        if (controller == _dobController && !_ageManual) {
          final age = _calculateAge(formatted);
          _ageController.text = age?.toString() ?? '';
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // phone validation
    if (_phoneController.text.isNotEmpty) {
      final phoneRegex = RegExp(r'^[\+]?[0-9]{6,15}$');
      if (!phoneRegex
          .hasMatch(_phoneController.text.replaceAll(RegExp(r'\s+'), ''))) {
        _showMessage('error', 'Please enter a valid phone number');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/accounts/hrs/${Uri.encodeComponent(_emailController.text)}/',
      );
      final request = http.MultipartRequest('PATCH', uri);

      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['fullname'] = _nameController.text;
      request.fields['phone'] = _phoneController.text;
      request.fields['department'] = _departmentController.text;
      request.fields['date_of_birth'] = _dobController.text;
      request.fields['date_joined'] = _dateJoinedController.text;
      if (_ageController.text.trim().isNotEmpty) {
        request.fields['age'] = _ageController.text.trim();
      }
      request.fields['qualification'] = _qualificationController.text;
      request.fields['skills'] = _skillsController.text;

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            _selectedImage!.path,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final updated = jsonDecode(response.body) as Map<String, dynamic>;

        // Store latest user_info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_info', jsonEncode(updated));

        setState(() {
          _isEditing = false;
          _selectedImage = null;
          _message = 'Profile updated successfully!';
          _messageType = 'success';
        });

        // Refresh from server (age/vintage etc.)
        await _fetchProfile();
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
      _showMessage('error', 'Failed to save profile changes: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _message = '';
          _messageType = '';
        });
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _message = '';
      _messageType = '';
    });
    _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'hr',
      child: Container(
        color: Colors.grey.shade100,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_message.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _messageType == 'success'
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _messageType == 'success'
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                _message,
                                style: TextStyle(
                                  color: _messageType == 'success'
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Center(child: _buildProfileImage()),
                          const SizedBox(height: 24),
                          _buildLabeledField(
                            icon: Icons.person,
                            label: 'Full Name',
                            child: TextFormField(
                              controller: _nameController,
                              enabled: _isEditing,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabeledField(
                            icon: Icons.email,
                            label: 'Email Address',
                            child: TextFormField(
                              controller: _emailController,
                              enabled: false,
                              decoration: _fieldDecoration().copyWith(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabeledField(
                            icon: Icons.phone,
                            label: 'Phone Number',
                            child: TextFormField(
                              controller: _phoneController,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration().copyWith(
                                hintText: 'Enter your phone number',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabeledField(
                            icon: Icons.business_center,
                            label: 'Department',
                            child: DropdownButtonFormField<String>(
                              value: _departmentController.text.isNotEmpty &&
                                      _departments
                                          .contains(_departmentController.text)
                                  ? _departmentController.text
                                  : null,
                              items: _departments
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isEditing
                                  ? (v) {
                                      setState(() {
                                        _departmentController.text = v ?? '';
                                      });
                                    }
                                  : null,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildLabeledField(
                                  icon: Icons.calendar_today,
                                  label: 'Date of Birth',
                                  child: TextFormField(
                                    controller: _dobController,
                                    readOnly: true,
                                    onTap: _isEditing
                                        ? () => _pickDate(_dobController)
                                        : null,
                                    decoration: _fieldDecoration(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildLabeledField(
                                  icon: Icons.cake,
                                  label: 'Age',
                                  child: TextFormField(
                                    controller: _ageController,
                                    enabled: _isEditing,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) {
                                      _ageManual = true;
                                    },
                                    decoration: _fieldDecoration(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildLabeledField(
                                  icon: Icons.date_range,
                                  label: 'Date Joined',
                                  child: TextFormField(
                                    controller: _dateJoinedController,
                                    readOnly: true,
                                    onTap: _isEditing
                                        ? () => _pickDate(_dateJoinedController)
                                        : null,
                                    decoration: _fieldDecoration(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildLabeledField(
                                  icon: Icons.timeline,
                                  label: 'Vintage',
                                  child: TextFormField(
                                    enabled: false,
                                    controller: TextEditingController(
                                      text: _calculateVintage(
                                          _dateJoinedController.text),
                                    ),
                                    decoration: _fieldDecoration().copyWith(
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabeledField(
                            icon: Icons.school,
                            label: 'Qualifications',
                            child: TextFormField(
                              controller: _qualificationController,
                              enabled: _isEditing,
                              decoration: _fieldDecoration().copyWith(
                                hintText: 'Enter your qualification',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabeledField(
                            icon: Icons.star,
                            label: 'Skills',
                            child: TextFormField(
                              controller: _skillsController,
                              enabled: _isEditing,
                              decoration: _fieldDecoration().copyWith(
                                hintText: 'Enter your skills',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (!_isEditing)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _isEditing = true);
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
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
                                    onPressed: _isSaving ? null : _cancelEdit,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
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
                                    onPressed:
                                        _isSaving ? null : _saveProfile,
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
                                        : const Icon(Icons.save, size: 18),
                                    label: Text(
                                      _isSaving
                                          ? 'Saving...'
                                          : 'Save Changes',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
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
          width: 96,
          height: 96,
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
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 48,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabeledField({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
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
      filled: _isEditing ? false : true,
      fillColor: _isEditing ? null : Colors.grey.shade100,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
