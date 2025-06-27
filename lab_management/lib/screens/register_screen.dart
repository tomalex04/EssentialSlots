import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isOtpVerified = false;
  bool isResendEnabled = true;
  int countdownSeconds = 60;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void startResendCountdown() {
    setState(() {
      isResendEnabled = false;
      countdownSeconds = 60;
    });

    // Start countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      setState(() {
        countdownSeconds--;
      });
      
      if (countdownSeconds <= 0) {
        setState(() {
          isResendEnabled = true;
        });
        return false;
      }
      return true;
    });
  }

  Future<void> sendOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    // Call backend to send OTP
    final success = await authProvider.sendOTP(emailController.text);
    
    if (success) {
      startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to email successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP')),
      );
    }
  }

  Future<void> verifyOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP')),
      );
      return;
    }

    // Call backend to verify OTP
    final success = await authProvider.verifyOTP(emailController.text, otpController.text);
    
    setState(() {
      isOtpVerified = success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'OTP verified successfully' : 'Invalid OTP')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: authProvider.usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authProvider.passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authProvider.confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email ID'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isResendEnabled ? sendOTP : null,
                      child: Text(
                        isResendEnabled 
                            ? 'Send OTP' 
                            : 'Resend OTP in ${countdownSeconds}s'
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  hintText: 'Enter the OTP sent to your email'
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: verifyOTP,
                child: const Text('Verify OTP'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isOtpVerified ? () async {
                  // Only allow registration if OTP is verified
                  if (emailController.text.isEmpty || phoneController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all fields')),
                    );
                    return;
                  }

                  String? errorMessage = await authProvider.register(
                    email: emailController.text,
                    phone: phoneController.text,
                  );
                  
                  if (errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Registration complete'), 
                        duration: Duration(seconds: 1)
                      ),
                    );
                    Navigator.pushReplacementNamed(context, '/login');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage), 
                        duration: const Duration(seconds: 1)
                      ),
                    );
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOtpVerified ? Colors.green : Colors.grey,
                ),
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}