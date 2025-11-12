import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/documents_service.dart';
import '../../services/profile_service.dart';

class EmployeeDocumentsUploadScreen extends StatefulWidget {
  const EmployeeDocumentsUploadScreen({super.key});

  @override
  State<EmployeeDocumentsUploadScreen> createState() => _EmployeeDocumentsUploadScreenState();
}

class _EmployeeDocumentsUploadScreenState extends State<EmployeeDocumentsUploadScreen> {
  final DocumentsService _documentsService = DocumentsService();
  final ProfileService _profileService = ProfileService();

  final Map<String, File> _selectedFiles = {};
  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;

  // Document configuration
  final Map<String, DocumentConfig> _documentConfig = {
    'tenth': DocumentConfig(
      label: '10th Marksheet',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'twelth': DocumentConfig(
      label: '12th Marksheet',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'resume': DocumentConfig(
      label: 'Resume',
      acceptedTypes: ['pdf', 'doc', 'docx'],
      maxSize: 2 * 1024 * 1024,
    ),
    'degree': DocumentConfig(
      label: 'Degree Certificate',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 10 * 1024 * 1024,
    ),
    'id_proof': DocumentConfig(
      label: 'ID Proof',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 2 * 1024 * 1024,
    ),
    'marks_card': DocumentConfig(
      label: 'Marks Card',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'award': DocumentConfig(
      label: 'Awards & Certifications',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'certificates': DocumentConfig(
      label: 'Certificates',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'masters': DocumentConfig(
      label: 'Masters Certificate',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 10 * 1024 * 1024,
    ),
    'appointment_letter': DocumentConfig(
      label: 'Appointment Letter',
      acceptedTypes: ['pdf', 'doc', 'docx'],
      maxSize: 5 * 1024 * 1024,
    ),
    'offer_letter': DocumentConfig(
      label: 'Offer Letter',
      acceptedTypes: ['pdf', 'doc', 'docx'],
      maxSize: 5 * 1024 * 1024,
    ),
    'releaving_letter': DocumentConfig(
      label: 'Releaving Letter',
      acceptedTypes: ['pdf', 'doc', 'docx'],
      maxSize: 5 * 1024 * 1024,
    ),
    'resignation_letter': DocumentConfig(
      label: 'Resignation Letter',
      acceptedTypes: ['pdf', 'doc', 'docx'],
      maxSize: 5 * 1024 * 1024,
    ),
    'achievement_crt': DocumentConfig(
      label: 'Achievement Certificate',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
    'bonafide_crt': DocumentConfig(
      label: 'Bonafide Certificate',
      acceptedTypes: ['pdf', 'jpg', 'jpeg', 'png'],
      maxSize: 5 * 1024 * 1024,
    ),
  };

  Future<void> _pickFile(String key) async {
    try {
      final config = _documentConfig[key]!;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: config.acceptedTypes,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Check file size
        final fileSize = await file.length();
        if (fileSize > config.maxSize) {
          setState(() {
            _errorMessage = '${config.label} exceeds max size of ${(config.maxSize / 1024 / 1024).toStringAsFixed(2)} MB';
          });
          return;
        }

        setState(() {
          _selectedFiles[key] = file;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  void _removeFile(String key) {
    setState(() {
      _selectedFiles.remove(key);
    });
  }

  Future<void> _uploadDocuments() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one document to upload';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final email = await _profileService.getUserEmail();
      if (email == null) {
        throw Exception('User email not found. Please login again.');
      }

      await _documentsService.updateDocuments(email, _selectedFiles);

      setState(() {
        _isUploading = false;
        _successMessage = 'Documents uploaded successfully!';
        _selectedFiles.clear();
      });

      // Navigate back after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Failed to upload documents: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select and upload your documents. You can update existing documents by uploading new ones.',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Success Message
            if (_successMessage != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error Message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Document Upload Cards
            ..._documentConfig.entries.map((entry) {
              final key = entry.key;
              final config = entry.value;
              final selectedFile = _selectedFiles[key];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              config.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (selectedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removeFile(key),
                              tooltip: 'Remove',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accepted: ${config.acceptedTypes.join(", ")} | Max: ${(config.maxSize / 1024 / 1024).toStringAsFixed(2)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedFile != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedFile.path.split('/').last,
                                  style: TextStyle(color: Colors.green.shade900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : () => _pickFile(key),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload),
                          SizedBox(width: 8),
                          Text('Upload Documents'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentConfig {
  final String label;
  final List<String> acceptedTypes;
  final int maxSize;

  DocumentConfig({
    required this.label,
    required this.acceptedTypes,
    required this.maxSize,
  });
}
