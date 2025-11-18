import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import '../services/api_service.dart';
import 'ceo/ceo_dashboard_screen.dart';
import 'ceo/ceo_employees_screen.dart';
import 'manager/manager_dashboard_screen.dart';
import 'employee/employee_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Form fields
  String _role = '';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI state
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Message state
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  Future<void> _loadLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_login_email');
    final lastRole = prefs.getString('last_login_role');
    if (!mounted) return;
    setState(() {
      if (lastEmail != null && lastEmail.isNotEmpty) {
        _emailController.text = lastEmail;
      }
      if (lastRole != null && lastRole.isNotEmpty) {
        _role = lastRole;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    // Clear previous messages
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_role.isEmpty) {
      setState(() {
        _errorMessage = 'Please select your role';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API endpoint matching Next.js structure
      final response = await _apiService.post('/accounts/login/', {
        'role': _role,
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      if (!mounted) return;

      if (response['success']) {
        final data = response['data'];

        // Check if user data exists and role matches
        if (data != null &&
            data['user'] != null &&
            data['user']['role'] == _role) {
          final user = data['user'];

          // Check if account is approved by admin
          if (user['is_staff'] == false) {
            setState(() {
              _errorMessage = 'Your account is waiting for admin approval.';
            });
            return;
          }

          // Store JWT token if backend provides it
          if (data['token'] != null) {
            await _apiService.saveToken(data['token']);
            print('JWT Token stored: ${data['token']}');
          } else {
            print('No JWT token returned from backend');
          }

          // Store user email and info using SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', user['email']);
          print('Logged-in user email: ${user['email']}');

          // Remember last login for convenience
          await prefs.setString('last_login_email', user['email']);
          await prefs.setString('last_login_role', user['role'] ?? _role);

          // Fetch full user profile data to get profile_picture
          String? profilePicture;
          try {
            final profileResponse = await _apiService.get(
              '/accounts/${_role}s/${user['email']}/',
            );
            if (profileResponse['success'] && profileResponse['data'] != null) {
              profilePicture = profileResponse['data']['profile_picture'];
              print('Fetched profile picture: $profilePicture');
            }
          } catch (e) {
            print('Error fetching profile picture: $e');
          }

          // Store user info
          await prefs.setString(
            'user_info',
            jsonEncode({
              'name': user['fullname'] ?? user['email'],
              'email': user['email'],
              'role': user['role'],
              'phone': user['phone'] ?? '',
              'department': user['department'] ?? '',
              'picture': user['picture'] ?? '',
              'profile_picture':
                  profilePicture ?? user['profile_picture'] ?? '',
            }),
          );

          print('Stored user info with profile picture: $profilePicture');

          setState(() {
            _successMessage = 'Login successful!';
          });

          // Navigate based on role
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;

          // Role-based navigation
          Widget dashboardScreen;
          switch (_role) {
            case 'ceo':
              dashboardScreen = const CeoDashboardScreen();
              break;
            case 'manager':
              dashboardScreen = const ManagerDashboardScreen();
              break;
            case 'hr':
              dashboardScreen = const CeoEmployeesScreen();
              break;
            case 'employee':
              dashboardScreen = const EmployeeDashboardScreen();
              break;
            case 'admin':
              dashboardScreen = const AdminDashboardScreen();
              break;
            default:
              dashboardScreen = const EmployeeDashboardScreen();
          }

          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => dashboardScreen));
        } else {
          setState(() {
            _errorMessage = 'Role mismatch or check your credentials.';
          });
        }
      } else {
        // Handle error response
        String errorMessage = 'Login failed. Check credentials.';

        final data = response['data'];
        if (data != null) {
          if (data['detail'] != null) {
            errorMessage = data['detail'];
          } else if (data['email'] != null &&
              data['email'] is List &&
              (data['email'] as List).isNotEmpty) {
            errorMessage = data['email'][0];
          } else if (data['password'] != null &&
              data['password'] is List &&
              (data['password'] as List).isNotEmpty) {
            errorMessage = data['password'][0];
          }
        } else if (response['error'] != null) {
          errorMessage = response['error'];
        }

        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Try again.';
      });
      print('Network/login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo and title
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.business_center,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Login form
                AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role Selection
                        const Text(
                          'Select Role',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _role.isEmpty ? null : _role,
                          decoration: InputDecoration(
                            hintText: 'Select your role',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ceo', child: Text('CEO')),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('Manager'),
                            ),
                            DropdownMenuItem(value: 'hr', child: Text('HR')),
                            DropdownMenuItem(
                              value: 'employee',
                              child: Text('Employee'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _role = value ?? '';
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your role';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Email field
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: InputDecoration(
                            hintText: 'your.email@company.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: _validateEmail,
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // Password field
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _handleLogin();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: _validatePassword,
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset coming soon'),
                                ),
                              );
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Logging in...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        // Message Display
                        if (_successMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade800,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
