import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.error ?? 'Registration failed'),
            backgroundColor: const Color(0xFFE11D48), // Rose color for errors
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else if (mounted) {
        // Show success message and navigate back to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful!'),
            backgroundColor: const Color(0xFF0D9488), // Teal for success
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.of(context).pop(); // Return to login screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFE11D48), // Rose color for errors
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF1F2937),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create your LitReview account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600, // Semibold
                        color: const Color(0xFF1F2937), // Dark gray for text
                        height: 1.5, // Line height
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details to create an account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400, // Regular
                        color: const Color(0xFF6B7280), // Medium gray for secondary text
                        height: 1.5, // Line height
                      ),
                    ),
                    const SizedBox(height: 32), // Larger section spacing
                    
                    // Username field
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _usernameController,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF1F2937), // Dark gray for text
                        ),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(
                            color: const Color(0xFF6B7280), // Medium gray
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: const Color(0xFF2563EB), // Primary blue
                              width: 1,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Email field
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF1F2937), // Dark gray for text
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: const Color(0xFF6B7280), // Medium gray
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: const Color(0xFF2563EB), // Primary blue
                              width: 1,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Password field
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF1F2937), // Dark gray for text
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: const Color(0xFF6B7280), // Medium gray
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF6B7280), // Medium gray
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: const Color(0xFF2563EB), // Primary blue
                              width: 1,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          helperText: 'Password must be at least 6 characters',
                          helperStyle: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Confirm password field
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 24),
                      child: TextFormField(
                        controller: _passwordConfirmController,
                        obscureText: !_isConfirmPasswordVisible,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF1F2937), // Dark gray for text
                        ),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(
                            color: const Color(0xFF6B7280), // Medium gray
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF6B7280), // Medium gray
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: const Color(0xFF2563EB), // Primary blue
                              width: 1,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Register button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF2563EB), // Primary deep blue
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500, // Medium
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF6B7280), // Medium gray
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Go back to login screen
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB), // Primary blue
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500, // Medium
                            ),
                          ),
                          child: const Text('Sign in'),
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
} 