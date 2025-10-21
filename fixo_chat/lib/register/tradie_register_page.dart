import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/dual_storage_service.dart';
import '../users/user_list_page.dart';

class TradieRegisterPage extends StatefulWidget {
  const TradieRegisterPage({super.key});

  @override
  _TradieRegisterPageState createState() => _TradieRegisterPageState();
}

class _TradieRegisterPageState extends State<TradieRegisterPage> {
  final _dualStorageService = DualStorageService();
  final _formKey = GlobalKey<FormState>();

  String firstName = '';
  String lastName = '';
  String middleName = '';
  String email = '';
  String phone = '';
  String password = '';
  String address = '';
  String city = '';
  String region = '';
  String postalCode = '';
  double? latitude;
  double? longitude;
  String businessName = '';
  String licenseNumber = '';
  String insuranceDetails = '';
  int? yearsExperience;
  double? hourlyRate;
  String availabilityStatus = 'available';
  int? serviceRadius;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Tradie')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'Enter first name' : null,
                      onChanged: (val) => firstName = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (val) =>
                          val!.isEmpty ? 'Enter last name' : null,
                      onChanged: (val) => lastName = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Middle Name (Optional)',
                      ),
                      onChanged: (val) => middleName = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (val) => val!.isEmpty ? 'Enter email' : null,
                      onChanged: (val) => email = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Phone (Optional)',
                      ),
                      onChanged: (val) => phone = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                      ),
                      onChanged: (val) => address = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'City (Optional)',
                      ),
                      onChanged: (val) => city = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Region (Optional)',
                      ),
                      onChanged: (val) => region = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Business Name (Optional)',
                      ),
                      onChanged: (val) => businessName = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'License Number (Optional)',
                      ),
                      onChanged: (val) => licenseNumber = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Years Experience (Optional)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => yearsExperience = int.tryParse(val),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate (Optional)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => hourlyRate = double.tryParse(val),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (val) =>
                          val!.length < 6 ? 'Password must be 6+ chars' : null,
                      obscureText: true,
                      onChanged: (val) => password = val,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: registerTradie,
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> registerTradie() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        UserCredential? userCredential = await _dualStorageService.registerUser(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          userType: 'tradie',
          middleName: middleName.isNotEmpty ? middleName : null,
          phone: phone.isNotEmpty ? phone : null,
          address: address.isNotEmpty ? address : null,
          city: city.isNotEmpty ? city : null,
          region: region.isNotEmpty ? region : null,
          postalCode: postalCode.isNotEmpty ? postalCode : null,
          latitude: latitude,
          longitude: longitude,
          businessName: businessName.isNotEmpty ? businessName : null,
          licenseNumber: licenseNumber.isNotEmpty ? licenseNumber : null,
          insuranceDetails: insuranceDetails.isNotEmpty
              ? insuranceDetails
              : null,
          yearsExperience: yearsExperience,
          hourlyRate: hourlyRate,
          availabilityStatus: availabilityStatus,
          serviceRadius: serviceRadius,
        );

        if (userCredential?.user != null && mounted) {
          // Navigate to user list
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserListPage(
                currentUserId: userCredential!.user!.uid,
                currentUserRole: 'tradie',
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
