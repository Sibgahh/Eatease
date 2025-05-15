import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth/auth_service.dart';
import '../../routes.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const RegisterScreen({super.key, required this.onLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final String _logPrefix = '[REGISTER_SCREEN]';
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  String _selectedRole = 'customer'; // Default role is customer
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    print('$_logPrefix Initializing register screen at ${DateTime.now().toIso8601String()}');
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    print('$_logPrefix Starting registration process');
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('$_logPrefix Form validation failed');
      setState(() {
        _errorMessage = 'Please fill in all required fields correctly';
      });
      return;
    }
    print('$_logPrefix Form validation passed');

    // Validate passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      print('$_logPrefix Passwords do not match');
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('$_logPrefix Attempting registration with email: ${_emailController.text.trim()}');
      print('$_logPrefix Selected role: $_selectedRole');
      
      final userId = await _authService.createUserWithRole(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _displayNameController.text.trim(),
        _phoneController.text.trim(),
        _selectedRole,
      );
      
      print('$_logPrefix Registration successful with userId: $userId');
      
      if (!mounted) {
        print('$_logPrefix Widget is not mounted, cannot navigate');
        return;
      }

      print('$_logPrefix Widget is mounted, proceeding with navigation');
      
      // Wait for a short moment to ensure Firebase state is updated
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Navigate to the appropriate screen based on role
      if (_selectedRole == 'merchant') {
        print('$_logPrefix Navigating to merchant screen');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.merchant,
          (route) => false,
        );
      } else {
        print('$_logPrefix Navigating to customer screen');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.customer,
          (route) => false,
        );
      }
    } catch (e) {
      print('$_logPrefix Registration error: $e');
      String errorMessage = 'Registration failed. ';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage += 'This email is already registered.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage += 'Password is too weak.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage += 'Invalid email address.';
      } else {
        errorMessage += 'Please try again.';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
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
    print('$_logPrefix Building register screen at ${DateTime.now().toIso8601String()}');
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF8BC34A),
                Color(0xFFAED581),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with shadow
                        Container(
                          height: screenSize.height * 0.12,
                          width: screenSize.height * 0.12,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Hero(
                            tag: 'appLogo',
                            child: Icon(
                              Icons.restaurant,
                              size: 50,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        
                        // App Name
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 3),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Subtitle
                        Text(
                          'Join EatEase today',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32.0),
                        
                        // Register Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Name Field
                                TextFormField(
                                  controller: _displayNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    hintText: 'Enter your full name',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                    ),
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'Enter your email',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF4CAF50)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                    ),
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    } else if (!value.contains('@') || !value.contains('.')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                
                                // Phone Field
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Student Number',
                                    hintText: 'Enter your student number',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    prefixIcon: Icon(Icons.school_outlined, color: Color(0xFF4CAF50)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                    ),
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your student number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                    ),
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    } else if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                
                                // Confirm Password Field
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _register(),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    hintText: 'Confirm your password',
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                    ),
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    } else if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                
                                // Role Selection
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    decoration: InputDecoration(
                                      labelText: 'Account Type',
                                      prefixIcon: Icon(Icons.account_circle_outlined, color: Color(0xFF4CAF50)),
                                      border: InputBorder.none,
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'customer',
                                        child: Text('Customer'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'merchant',
                                        child: Text('Merchant'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRole = value!;
                                      });
                                    },
                                  ),
                                ),
                                
                                const SizedBox(height: 24.0),
                                
                                // Error Message
                                if (_errorMessage.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage,
                                            style: TextStyle(color: Colors.red.shade800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_errorMessage.isNotEmpty) const SizedBox(height: 20.0),
                                
                                // Register Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 3,
                                    disabledBackgroundColor: Color(0xFF4CAF50).withOpacity(0.6),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 17.0,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24.0),
                        
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            TextButton(
                              onPressed: () {
                                // Start reverse animation before navigating
                                _animationController.reverse().then((_) {
                                  widget.onLogin();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
        ),
      ),
    );
  }
} 