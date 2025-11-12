import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/employee_profile_model.dart';
import '../../models/employee_documents_model.dart';
import '../../services/profile_service.dart';
import '../../services/documents_service.dart';
import 'employee_documents_upload_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final DocumentsService _documentsService = DocumentsService();
  final ImagePicker _imagePicker = ImagePicker();

  EmployeeProfile? profile;
  EmployeeProfile? originalProfile;
  List<Manager> managers = [];
  List<Department> departments = [];
  EmployeeDocuments? documents;

  bool isLoading = true;
  bool isEditing = false;
  bool isSaving = false;
  bool isLoadingDocuments = true;
  String? errorMessage;
  String? successMessage;

  File? selectedImage;
  String? localImagePath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    debugPrint('🔹 Starting profile load...');
    setState(() => isLoading = true);

    try {
      final email = await _profileService.getUserEmail();
      debugPrint('📧 Retrieved email: $email');
      if (email == null) {
        debugPrint(
          '⚠️ No email found. Likely user not logged in or SharedPreferences empty.',
        );
        throw Exception('User email not found. Please login again.');
      }

      // Fetch real data from API
      final fetchedProfile = await _profileService.fetchProfile(email);
      final fetchedManagers = await _profileService.fetchManagers();
      final fetchedDepartments = await _profileService.fetchDepartments();

      debugPrint('✅ Profile, managers, and departments fetched successfully');
      if (!mounted) return;
      setState(() {
        profile = fetchedProfile;
        originalProfile = fetchedProfile;
        managers = fetchedManagers;
        departments = fetchedDepartments;
        isLoading = false;
        errorMessage = null;
      });

      // Load documents separately
      _loadDocuments(email);
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        profile = null; // ensure spinner stops
        errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timed out. Please check your internet connection or try again.'
            : e.toString();
      });
    }
  }

  Future<void> _loadDocuments(String email) async {
    if (!mounted) return;
    setState(() => isLoadingDocuments = true);

    try {
      final fetchedDocuments = await _documentsService.fetchDocuments(email);
      debugPrint('✅ Documents fetched successfully');
      if (!mounted) return;
      setState(() {
        documents = fetchedDocuments;
        isLoadingDocuments = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading documents: $e');
      if (!mounted) return;
      setState(() {
        isLoadingDocuments = false;
      });
    }
  }

  String _calculateAge(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final dob = DateTime.parse(dateString);
      final today = DateTime.now();

      int years = today.year - dob.year;
      int months = today.month - dob.month;
      int days = today.day - dob.day;

      if (days < 0) {
        months--;
        final prevMonth = DateTime(today.year, today.month, 0);
        days += prevMonth.day;
      }
      if (months < 0) {
        years--;
        months += 12;
      }
      if (years < 0) return '';

      return '$years year${years != 1 ? 's' : ''}, $months month${months != 1 ? 's' : ''}, $days day${days != 1 ? 's' : ''}';
    } catch (e) {
      return '';
    }
  }

  String _calculateVintage(String? dateString) {
    return _calculateAge(dateString); // Same calculation
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
          localImagePath = image.path;
        });
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<void> _saveProfile() async {
    if (profile == null) return;

    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      await _profileService.updateProfile(
        profile!,
        profileImage: selectedImage,
      );

      if (!mounted) return;
      setState(() {
        isSaving = false;
        isEditing = false;
        originalProfile = profile;
        selectedImage = null;
        localImagePath = null;
      });

      _showMessage('Profile updated successfully!');
      _loadData(); // Reload to get updated data
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Failed to save profile: $e', isError: true);
    }
  }

  void _cancelEdit() {
    setState(() {
      profile = originalProfile;
      isEditing = false;
      selectedImage = null;
      localImagePath = null;
      errorMessage = null;
      successMessage = null;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      if (isError) {
        errorMessage = message;
        successMessage = null;
      } else {
        successMessage = message;
        errorMessage = null;
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          errorMessage = null;
          successMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMessage ?? 'Failed to load profile'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  originalProfile = profile;
                  isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success/Error Messages
            if (successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),

            // Personal Information
            _buildSection('Personal Information', [
              _buildTextField(
                'Full Name',
                profile!.fullname,
                (val) => profile!.fullname = val,
                icon: Icons.person,
              ),
              _buildTextField(
                'Email',
                profile!.email,
                null,
                enabled: false,
                icon: Icons.email,
              ),
              _buildTextField(
                'Phone',
                profile!.phone ?? '',
                (val) => profile!.phone = val,
                icon: Icons.phone,
              ),
              _buildDateField(
                'Date of Birth',
                profile!.dateOfBirth,
                (val) => profile!.dateOfBirth = val,
              ),
              if (profile!.dateOfBirth != null &&
                  profile!.dateOfBirth!.isNotEmpty)
                _buildReadOnlyField('Age', _calculateAge(profile!.dateOfBirth)),
              _buildTextField(
                'Gender',
                profile!.gender ?? '',
                (val) => profile!.gender = val,
              ),
              _buildTextField(
                'Marital Status',
                profile!.maritalStatus ?? '',
                (val) => profile!.maritalStatus = val,
              ),
              _buildTextField(
                'Nationality',
                profile!.nationality ?? '',
                (val) => profile!.nationality = val,
              ),
            ]),

            // Employment Details
            _buildSection('Employment Details', [
              _buildDropdownField(
                'Department',
                profile!.department,
                departments.map((d) => d.departmentName).toList(),
                (val) => profile!.department = val,
              ),
              _buildTextField(
                'Designation',
                profile!.designation ?? '',
                (val) => profile!.designation = val,
                icon: Icons.work,
              ),
              _buildDateField(
                'Joining Date',
                profile!.dateJoined,
                (val) => profile!.dateJoined = val,
              ),
              if (profile!.dateJoined != null &&
                  profile!.dateJoined!.isNotEmpty)
                _buildReadOnlyField(
                  'Vintage',
                  _calculateVintage(profile!.dateJoined),
                ),
              _buildTextField(
                'Employee ID',
                profile!.empId ?? '',
                (val) => profile!.empId = val,
              ),
              _buildTextField(
                'Employment Type',
                profile!.employmentType ?? '',
                (val) => profile!.employmentType = val,
              ),
              _buildTextField(
                'Work Location',
                profile!.workLocation ?? '',
                (val) => profile!.workLocation = val,
              ),
              _buildTextField(
                'Team',
                profile!.team ?? '',
                (val) => profile!.team = val,
              ),
              _buildManagerDropdown(),
            ]),

            // Education & Skills
            _buildSection('Education & Skills', [
              _buildTextField(
                'Degree',
                profile!.degree ?? '',
                (val) => profile!.degree = val,
              ),
              _buildTextField(
                'Passout Year',
                profile!.degreePassoutYear ?? '',
                (val) => profile!.degreePassoutYear = val,
              ),
              _buildTextField(
                'Institution',
                profile!.institution ?? '',
                (val) => profile!.institution = val,
              ),
              _buildTextField(
                'Grade',
                profile!.grade ?? '',
                (val) => profile!.grade = val,
              ),
              _buildTextField(
                'Skills',
                profile!.skills ?? '',
                (val) => profile!.skills = val,
              ),
              _buildTextField(
                'Languages',
                profile!.languages ?? '',
                (val) => profile!.languages = val,
              ),
            ]),

            // Emergency Contact
            _buildSection('Emergency Contact', [
              _buildTextField(
                'Contact Name',
                profile!.emergencyContactName ?? '',
                (val) => profile!.emergencyContactName = val,
              ),
              _buildTextField(
                'Relationship',
                profile!.emergencyContactRelationship ?? '',
                (val) => profile!.emergencyContactRelationship = val,
              ),
              _buildTextField(
                'Contact Number',
                profile!.emergencyContactNo ?? '',
                (val) => profile!.emergencyContactNo = val,
              ),
            ]),

            // Addresses
            _buildSection('Addresses', [
              _buildTextField(
                'Residential Address',
                profile!.residentialAddress ?? '',
                (val) => profile!.residentialAddress = val,
              ),
              _buildTextField(
                'Permanent Address',
                profile!.permanentAddress ?? '',
                (val) => profile!.permanentAddress = val,
              ),
              _buildTextField(
                'Home Address',
                profile!.homeAddress ?? '',
                (val) => profile!.homeAddress = val,
              ),
            ]),

            // Additional Information
            _buildSection('Additional Information', [
              _buildTextField(
                'Blood Group',
                profile!.bloodGroup ?? '',
                (val) => profile!.bloodGroup = val,
              ),
              _buildTextField(
                'Father Name',
                profile!.fatherName ?? '',
                (val) => profile!.fatherName = val,
              ),
              _buildTextField(
                'Father Contact',
                profile!.fatherContact ?? '',
                (val) => profile!.fatherContact = val,
              ),
              _buildTextField(
                'Mother Name',
                profile!.motherName ?? '',
                (val) => profile!.motherName = val,
              ),
              _buildTextField(
                'Mother Contact',
                profile!.motherContact ?? '',
                (val) => profile!.motherContact = val,
              ),
              _buildTextField(
                'Wife Name',
                profile!.wifeName ?? '',
                (val) => profile!.wifeName = val,
              ),
              _buildTextField(
                'Total Siblings',
                profile!.totalSiblings ?? '',
                (val) => profile!.totalSiblings = val,
              ),
              _buildTextField(
                'Brothers',
                profile!.brothers ?? '',
                (val) => profile!.brothers = val,
              ),
              _buildTextField(
                'Sisters',
                profile!.sisters ?? '',
                (val) => profile!.sisters = val,
              ),
              _buildTextField(
                'Total Children',
                profile!.totalChildren ?? '',
                (val) => profile!.totalChildren = val,
              ),
            ]),

            // Bank Details
            _buildSection('Bank Details', [
              _buildTextField(
                'Account Number',
                profile!.accountNumber ?? '',
                (val) => profile!.accountNumber = val,
              ),
              _buildTextField(
                'Bank Name',
                profile!.bankName ?? '',
                (val) => profile!.bankName = val,
              ),
              _buildTextField(
                'Branch',
                profile!.branch ?? '',
                (val) => profile!.branch = val,
              ),
              _buildTextField(
                'IFSC Code',
                profile!.ifsc ?? '',
                (val) => profile!.ifsc = val,
              ),
              _buildTextField(
                'PF Number',
                profile!.pfNo ?? '',
                (val) => profile!.pfNo = val,
              ),
              _buildTextField(
                'PF UAN',
                profile!.pfUan ?? '',
                (val) => profile!.pfUan = val,
              ),
            ]),

            // Documents Section
            _buildDocumentsSection(),

            const SizedBox(height: 24),

            // Action Buttons
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text('Save Changes'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: localImagePath != null
                      ? FileImage(File(localImagePath!))
                      : (profile!.profilePicture != null &&
                                    profile!.profilePicture!.isNotEmpty
                                ? NetworkImage(profile!.profilePicture!)
                                : null)
                            as ImageProvider?,
                  child:
                      (localImagePath == null &&
                          (profile!.profilePicture == null ||
                              profile!.profilePicture!.isEmpty))
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey.shade600,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                if (isEditing)
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Change Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String)? onChanged, {
    bool enabled = true,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        enabled: isEditing && enabled,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: const OutlineInputBorder(),
          filled: !isEditing || !enabled,
          fillColor: !isEditing || !enabled ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    String? value,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        enabled: isEditing,
        readOnly: true,
        onTap: isEditing
            ? () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: value != null && value.isNotEmpty
                      ? DateTime.tryParse(value) ?? DateTime.now()
                      : DateTime.now(),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  onChanged(DateFormat('yyyy-MM-dd').format(date));
                  setState(() {});
                }
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          border: const OutlineInputBorder(),
          filled: !isEditing,
          fillColor: !isEditing ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && options.contains(value) ? value : null,
        items: options.map((option) {
          return DropdownMenuItem(value: option, child: Text(option));
        }).toList(),
        onChanged: isEditing ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !isEditing,
          fillColor: !isEditing ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  Widget _buildManagerDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: profile!.reportsTo,
        isExpanded: true, // Prevent overflow
        items: managers.map((manager) {
          return DropdownMenuItem(
            value: manager.email,
            child: Text(
              manager.fullname,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: isEditing
            ? (val) => setState(() => profile!.reportsTo = val)
            : null,
        decoration: InputDecoration(
          labelText: 'Reports To',
          border: const OutlineInputBorder(),
          filled: !isEditing,
          fillColor: !isEditing ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Documents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmployeeDocumentsUploadScreen(),
                      ),
                    );
                    // Reload documents if upload was successful
                    if (result == true) {
                      final email = await _profileService.getUserEmail();
                      if (email != null) {
                        _loadDocuments(email);
                      }
                    }
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoadingDocuments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (documents == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'No documents uploaded yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmployeeDocumentsUploadScreen(),
                            ),
                          );
                          if (result == true) {
                            final email = await _profileService.getUserEmail();
                            if (email != null) {
                              _loadDocuments(email);
                            }
                          }
                        },
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload Documents'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildDocumentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    final allDocs = documents!.getAllDocuments();
    final availableDocs = allDocs.entries
        .where((entry) => entry.value.isAvailable)
        .toList();

    if (availableDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No documents uploaded yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: availableDocs.map((entry) {
        final docInfo = entry.value;
        final fileName = docInfo.url!.split('/').last;
        final fileExtension = fileName.split('.').last.toLowerCase();
        
        IconData iconData;
        Color iconColor;
        
        switch (fileExtension) {
          case 'pdf':
            iconData = Icons.picture_as_pdf;
            iconColor = Colors.red;
            break;
          case 'doc':
          case 'docx':
            iconData = Icons.description;
            iconColor = Colors.blue;
            break;
          case 'jpg':
          case 'jpeg':
          case 'png':
          case 'gif':
            iconData = Icons.image;
            iconColor = Colors.green;
            break;
          default:
            iconData = Icons.insert_drive_file;
            iconColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          child: ListTile(
            leading: Icon(iconData, color: iconColor, size: 32),
            title: Text(
              docInfo.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              fileName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () => _openDocument(docInfo.url!),
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.green),
                  onPressed: () => _downloadDocument(docInfo.url!, fileName),
                  tooltip: 'Download',
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _downloadDocument(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $fileName...')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not download document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading document: $e')),
        );
      }
    }
  }
}
