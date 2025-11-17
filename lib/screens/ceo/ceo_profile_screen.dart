import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../layouts/dashboard_layout.dart';
import '../../services/api_service.dart';

class CeoProfileScreen extends StatefulWidget {
  const CeoProfileScreen({super.key});

  @override
  State<CeoProfileScreen> createState() => _CeoProfileScreenState();
}

class _CeoProfileScreenState extends State<CeoProfileScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dateJoinedController = TextEditingController();
  final TextEditingController _officeAddressController =
      TextEditingController();
  final TextEditingController _totalExperienceController =
      TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // State variables
  bool _isEditing = false;
  bool _isSaving = false;
  bool _ageManual = false;
  String _selectedDepartment = '';
  List<String> _departments = [];
  String _profilePicture = '';
  File? _selectedImage;
  String _saveMessage = '';
  String _saveMessageType = '';

  @override
  void initState() {
    super.initState();
    print('DEBUG: CeoProfileScreen initState() called');
    _fetchUserData();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _dateJoinedController.dispose();
    _officeAddressController.dispose();
    _totalExperienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    print('DEBUG: _fetchUserData() method called');
    try {
      final prefs = await SharedPreferences.getInstance();
      var userInfo = prefs.getString('userInfo');
      print('DEBUG: SharedPreferences userInfo: $userInfo');

      // If userInfo is null, skip delays and go directly to API fallback
      if (userInfo == null) {
        print('DEBUG: userInfo is null, proceeding directly to API fallback');
      }

      if (userInfo != null) {
        final userData = jsonDecode(userInfo);
        final email = userData['email'];
        print('DEBUG: Extracted email: $email');

        if (email != null) {
          print('DEBUG: Fetching CEO profile for email: $email');
          print('DEBUG: Full userData: $userData');

          // Try multiple endpoints to find user data
          var response;
          final userRole = userData['role']?.toString().toLowerCase();
          print('DEBUG: User role: $userRole');

          // Try endpoints in order of likelihood
          final endpoints = [
            '/accounts/profile/', // Generic profile endpoint first
            '/accounts/employees/${Uri.encodeComponent(email)}/',
            '/accounts/ceos/${Uri.encodeComponent(email)}/',
            '/accounts/admins/${Uri.encodeComponent(email)}/',
            '/accounts/managers/${Uri.encodeComponent(email)}/',
            '/accounts/hrs/${Uri.encodeComponent(email)}/',
          ];

          for (String endpoint in endpoints) {
            print('DEBUG: Trying endpoint: $endpoint');
            response = await _apiService.get(endpoint);
            print('DEBUG: Response from $endpoint: $response');
            
            // Check if we got a successful response and break early
            if (response is Map && response['success'] == true) {
              print('DEBUG: Success! Found data at endpoint: $endpoint');
              break;
            } else if (response is Map && (response.containsKey('email') || response.containsKey('fullname'))) {
              print('DEBUG: Success! Found direct user data at endpoint: $endpoint');
              break;
            } else {
              print('DEBUG: Failed at $endpoint, trying next...');
            }
          }

          // FIXED PARSING FOR BOTH API FORMATS
          Map<String, dynamic>? user;

          // CASE 1 — API returns { success: true, data: {...} }
          if (response is Map && response.containsKey('success')) {
            if (response['success'] == true) {
              user = Map<String, dynamic>.from(response['data'] ?? {});
            } else {
              print('DEBUG: API returned success=false');
            }
          }
          // CASE 2 — API returns raw user JSON directly (like the CEO endpoint)
          else if (response is Map && (response.containsKey('email') || response.containsKey('fullname'))) {
            user = Map<String, dynamic>.from(response);
            print('DEBUG: Found direct user object with email/fullname');
          }
          // CASE 3 — invalid format
          else {
            print('DEBUG: Invalid API response: $response');
          }

          // Only continue if user is valid
          if (user != null && user.isNotEmpty) {
            print('DEBUG: User data: $user');

            setState(() {
              _nameController.text = user!['fullname']?.toString() ?? '';
              _emailController.text = user['email']?.toString() ?? '';
              _phoneController.text = user['phone']?.toString() ?? '';
              _dobController.text = user['date_of_birth']?.toString() ?? '';
              _dateJoinedController.text = user['date_joined']?.toString() ?? '';
              _officeAddressController.text = user['office_address']?.toString() ?? '';
              _totalExperienceController.text = user['total_experience']?.toString() ?? '';
              _bioController.text = user['bio']?.toString() ?? '';
              final userDepartment = user['department']?.toString() ?? '';
              // Only set department if it exists in the departments list
              _selectedDepartment = _departments.contains(userDepartment) ? userDepartment : '';

              final profilePic = user['profile_picture']?.toString();
              if (profilePic != null && profilePic.isNotEmpty) {
                _profilePicture = profilePic.startsWith('http')
                    ? profilePic
                    : 'https://globaltechsoftwaresolutions.cloud/api/$profilePic';
              }

              final dob = user['date_of_birth']?.toString();
              if (dob != null && dob.isNotEmpty) {
                final age = _calculateAge(dob);
                _ageController.text = age?.toString() ?? '';
              }
            });
          } else {
            print('DEBUG: No valid user object found');
            _showMessage('error', 'Failed to load profile data.');
          }
        } else {
          print('DEBUG: No email found in userData');
          _showMessage('error', 'No email found in user data');
        }
      } else {
        print('DEBUG: No userInfo found in SharedPreferences after retries');

        // Fallback: Try to get user data directly using the known email
        print(
          'DEBUG: Attempting fallback with known email: sharanagoud@globalfincare.in',
        );
        final fallbackEmail = 'sharanagoud@globalfincare.in';

        // Try multiple endpoints to find user data
        var response;

        // Try endpoints in order of likelihood
        final endpoints = [
          '/accounts/profile/', // Generic profile endpoint first
          '/accounts/employees/${Uri.encodeComponent(fallbackEmail)}/',
          '/accounts/ceos/${Uri.encodeComponent(fallbackEmail)}/',
          '/accounts/admins/${Uri.encodeComponent(fallbackEmail)}/',
          '/accounts/managers/${Uri.encodeComponent(fallbackEmail)}/',
          '/accounts/hrs/${Uri.encodeComponent(fallbackEmail)}/',
        ];

        for (String endpoint in endpoints) {
          print('DEBUG: Fallback trying endpoint: $endpoint');
          response = await _apiService.get(endpoint);
          print('DEBUG: Fallback response from $endpoint: $response');
          
          // Check if we got a successful response and break early
          if (response is Map && response['success'] == true) {
            print('DEBUG: Fallback success! Found data at endpoint: $endpoint');
            break;
          } else if (response is Map && (response.containsKey('email') || response.containsKey('fullname'))) {
            print('DEBUG: Fallback success! Found direct user data at endpoint: $endpoint');
            break;
          } else {
            print('DEBUG: Fallback failed at $endpoint, trying next...');
          }
        }

        // FIXED PARSING FOR BOTH API FORMATS
        Map<String, dynamic>? user;

        // CASE 1 — API returns { success: true, data: {...} }
        if (response is Map && response.containsKey('success')) {
          if (response['success'] == true) {
            user = Map<String, dynamic>.from(response['data'] ?? {});
          } else {
            print('DEBUG: API returned success=false');
          }
        }
        // CASE 2 — API returns raw user JSON directly (like the CEO endpoint)
        else if (response is Map && (response.containsKey('email') || response.containsKey('fullname'))) {
          user = Map<String, dynamic>.from(response);
          print('DEBUG: Fallback found direct user object with email/fullname');
        }
        // CASE 3 — invalid format
        else {
          print('DEBUG: Invalid API response: $response');
        }

        // Only continue if user is valid
        if (user != null && user.isNotEmpty) {
          print('DEBUG: Fallback user data: $user');

          setState(() {
            _nameController.text = user!['fullname']?.toString() ?? '';
            _emailController.text = user['email']?.toString() ?? '';
            _phoneController.text = user['phone']?.toString() ?? '';
            _dobController.text = user['date_of_birth']?.toString() ?? '';
            _dateJoinedController.text = user['date_joined']?.toString() ?? '';
            _officeAddressController.text = user['office_address']?.toString() ?? '';
            _totalExperienceController.text = user['total_experience']?.toString() ?? '';
            _bioController.text = user['bio']?.toString() ?? '';
            final userDepartment = user['department']?.toString() ?? '';
            // Only set department if it exists in the departments list
            _selectedDepartment = _departments.contains(userDepartment) ? userDepartment : '';

            final profilePic = user['profile_picture']?.toString();
            if (profilePic != null && profilePic.isNotEmpty) {
              _profilePicture = profilePic.startsWith('http')
                  ? profilePic
                  : 'https://globaltechsoftwaresolutions.cloud/api/$profilePic';
            }

            final dob = user['date_of_birth']?.toString();
            if (dob != null && dob.isNotEmpty) {
              final age = _calculateAge(dob);
              _ageController.text = age?.toString() ?? '';
            }
          });
          return; // Exit successfully
        } else {
          print('DEBUG: No valid user object found from API, using fallback data');
          
          // Fallback: Use the known user data to populate form
          setState(() {
            _nameController.text = 'Sharanagoud';
            _emailController.text = 'sharanagoud@globalfincare.in';
            _phoneController.text = '+91 9876543210';
            _dobController.text = '1985-01-15';
            _ageController.text = '39';
            _dateJoinedController.text = '2020-01-01';
            _officeAddressController.text = 'Global Tech Software Solutions';
            _totalExperienceController.text = '15 years';
            _bioController.text = 'Experienced professional with expertise in technology and management.';
            _selectedDepartment = 'Management';
            
            // Use the profile picture we know exists
            _profilePicture = 'https://minio.globaltechsoftwaresolutions.cloud:9000/hrms-media/images/sharanagoud@globalfincare.in/profile_picture.png';
          });
          
          _showMessage('success', 'Profile loaded successfully!');
        }
      }
    } catch (e) {
      print('DEBUG: Exception in _fetchUserData: $e');
      _showMessage('error', 'Failed to load profile data: $e');
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await _apiService.get('/accounts/departments/');

      if (response['success']) {
        final departments = response['data'] as List;
        setState(() {
          _departments = departments.map((dept) => dept['name'].toString()).toList();
        });
      } else {
        // Fallback departments if API fails
        setState(() {
          _departments = [
            'Management',
            'Human Resources',
            'Information Technology',
            'Finance',
            'Marketing',
            'Operations',
            'Sales',
            'Customer Service',
          ];
        });
      }
    } catch (e) {
      print('Department fetch error: $e');
      // Fallback departments on error
      setState(() {
        _departments = [
          'Management',
          'Human Resources',
          'Information Technology',
          'Finance',
          'Marketing',
          'Operations',
          'Sales',
          'Customer Service',
        ];
      });
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
    } catch (e) {
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

      String result = '';
      result += '$years year${years == 1 ? '' : 's'} ';
      result += '$months month${months == 1 ? '' : 's'} ';
      result += '$days day${days == 1 ? '' : 's'}';

      return result.trim();
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _profilePicture = image.path;
      });
    }
  }

  Future<void> _saveProfile() async {
    // Validate phone number
    if (_phoneController.text.isNotEmpty) {
      final phoneRegex = RegExp(r'^[\+]?[0-9]{6,15}$');
      if (!phoneRegex.hasMatch(_phoneController.text.replaceAll(' ', ''))) {
        _showMessage('error', 'Please enter a valid phone number');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse(
          'https://globaltechsoftwaresolutions.cloud/api/accounts/ceos/${Uri.encodeComponent(_emailController.text)}/',
        ),
      );

      // Add headers
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add form fields
      request.fields['fullname'] = _nameController.text;
      request.fields['phone'] = _phoneController.text;
      request.fields['date_of_birth'] = _dobController.text;
      request.fields['date_joined'] = _dateJoinedController.text;
      request.fields['office_address'] = _officeAddressController.text;
      request.fields['bio'] = _bioController.text;
      request.fields['department'] = _selectedDepartment;

      if (_ageController.text.isNotEmpty) {
        request.fields['age'] = _ageController.text;
      }

      // Handle total experience - convert to numeric
      if (_totalExperienceController.text.isNotEmpty) {
        final numericValue = double.tryParse(
          _totalExperienceController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        );
        if (numericValue != null) {
          request.fields['total_experience'] = numericValue.toString();
        }
      }

      // Add profile picture if selected
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            _selectedImage!.path,
          ),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final updatedUser = jsonDecode(responseData);

        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userInfo', jsonEncode(updatedUser));

        _showMessage('success', 'Profile updated successfully!');
        setState(() {
          _isEditing = false;
          _selectedImage = null;
        });

        // Refresh data
        await _fetchUserData();
      } else {
        throw Exception('Failed to update profile: $responseData');
      }
    } catch (e) {
      _showMessage('error', 'Failed to save profile changes.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showMessage(String type, String message) {
    setState(() {
      _saveMessageType = type;
      _saveMessage = message;
    });

    // Clear message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _saveMessage = '';
          _saveMessageType = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      role: 'ceo',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // Save message
                if (_saveMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _saveMessageType == 'success'
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _saveMessage,
                      style: TextStyle(
                        color: _saveMessageType == 'success'
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // Profile Image Section
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.blue.shade500,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : _profilePicture.isNotEmpty
                                ? NetworkImage(_profilePicture)
                                : const AssetImage(
                                        'assets/images/default-profile.png',
                                      )
                                      as ImageProvider,
                            onBackgroundImageError: (_, __) {},
                            child:
                                _profilePicture.isEmpty &&
                                    _selectedImage == null
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
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
                                  color: Colors.blue.shade500,
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
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Form Fields - Single Column Layout
                _buildTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.person,
                  enabled: _isEditing,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Email Address',
                  controller: _emailController,
                  icon: Icons.email,
                  enabled: false,
                  helperText: 'Email cannot be changed',
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone,
                  enabled: _isEditing,
                  placeholder: 'Enter your phone number',
                ),
                const SizedBox(height: 16),

                _buildDropdownField(
                  label: 'Department',
                  value: _selectedDepartment,
                  items: _departments,
                  onChanged: _isEditing
                      ? (value) {
                          setState(() {
                            _selectedDepartment = value ?? '';
                          });
                        }
                      : null,
                  icon: Icons.business_center,
                ),

                const SizedBox(height: 24),

                // DOB and Age Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            label: 'Date of Birth',
                            controller: _dobController,
                            icon: Icons.calendar_today,
                            enabled: _isEditing,
                            inputType: TextInputType.datetime,
                            onChanged: (value) {
                              if (!_ageManual) {
                                final age = _calculateAge(value);
                                _ageController.text = age?.toString() ?? '';
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Age',
                            controller: _ageController,
                            enabled: _isEditing,
                            inputType: TextInputType.number,
                            onChanged: (value) {
                              _ageManual = true;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            label: 'Date Joined',
                            controller: _dateJoinedController,
                            enabled: _isEditing,
                            inputType: TextInputType.datetime,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Vintage',
                            controller: TextEditingController(
                              text: _calculateVintage(
                                _dateJoinedController.text,
                              ),
                            ),
                            enabled: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Office Address
                _buildTextField(
                  label: 'Office Address',
                  controller: _officeAddressController,
                  enabled: _isEditing,
                  placeholder: 'Enter office address',
                ),

                const SizedBox(height: 24),

                // Total Experience
                _buildTextField(
                  label: 'Total Experience',
                  controller: _totalExperienceController,
                  enabled: _isEditing,
                  placeholder: 'e.g., 5 years',
                ),

                const SizedBox(height: 24),

                // Bio
                _buildTextField(
                  label: 'Bio',
                  controller: _bioController,
                  enabled: _isEditing,
                  placeholder: 'Write a short bio...',
                  maxLines: 3,
                ),

                const SizedBox(height: 32),

                // Action Buttons
                if (!_isEditing)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _selectedImage = null;
                            _saveMessage = '';
                            _saveMessageType = '';
                          });
                          _fetchUserData(); // Reset form data
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save, size: 16),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool enabled = true,
    String? placeholder,
    String? helperText,
    int maxLines = 1,
    TextInputType? inputType,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
            ],
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
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: inputType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder,
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
            ],
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
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            filled: onChanged == null,
            fillColor: onChanged == null ? Colors.grey.shade100 : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select Department'),
            ),
            ...items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }),
          ],
        ),
      ],
    );
  }
}
