import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/dual_storage_service.dart';
import '../users/user_list_page.dart';

class HomeOwnerRegisterPage extends StatefulWidget {
  const HomeOwnerRegisterPage({super.key});

  @override
  _HomeOwnerRegisterPageState createState() => _HomeOwnerRegisterPageState();
}

class _HomeOwnerRegisterPageState extends State<HomeOwnerRegisterPage> {
  final _dualStorageService = DualStorageService();
  final _formKey = GlobalKey<FormState>();

  String firstName = '';
  String lastName = '';
  String email = '';
  String phone = '';
  String password = '';
  String address = '';
  String city = '';
  String region = '';
  String postalCode = '';
  double? latitude;
  double? longitude;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register as Homeowner')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(labelText: 'First Name'),
                      validator: (val) =>
                          val!.isEmpty ? 'Enter first name' : null,
                      onChanged: (val) => firstName = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Last Name'),
                      validator: (val) =>
                          val!.isEmpty ? 'Enter last name' : null,
                      onChanged: (val) => lastName = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (val) => val!.isEmpty ? 'Enter email' : null,
                      onChanged: (val) => email = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Phone (Optional)',
                      ),
                      onChanged: (val) => phone = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Address (Optional)',
                      ),
                      onChanged: (val) => address = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'City (Optional)'),
                      onChanged: (val) => city = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Region (Optional)',
                      ),
                      onChanged: (val) => region = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Postal Code (Optional)',
                      ),
                      onChanged: (val) => postalCode = val,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Password'),
                      validator: (val) =>
                          val!.length < 6 ? 'Password must be 6+ chars' : null,
                      obscureText: true,
                      onChanged: (val) => password = val,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: registerHomeowner,
                      child: Text('Register'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> registerHomeowner() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        UserCredential? userCredential = await _dualStorageService.registerUser(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          userType: 'homeowner',
          phone: phone.isNotEmpty ? phone : null,
          address: address.isNotEmpty ? address : null,
          city: city.isNotEmpty ? city : null,
          region: region.isNotEmpty ? region : null,
          postalCode: postalCode.isNotEmpty ? postalCode : null,
          latitude: latitude,
          longitude: longitude,
        );

        if (userCredential?.user != null && mounted) {
          // Navigate to user list
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserListPage(
                currentUserId: userCredential!.user!.uid,
                currentUserRole: 'homeowner',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }
}
