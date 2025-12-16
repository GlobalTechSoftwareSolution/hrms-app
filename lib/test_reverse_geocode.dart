import 'package:flutter/material.dart';
import 'package:smart_hr/services/reverse_geocode_service.dart';

class TestReverseGeocodeScreen extends StatefulWidget {
  const TestReverseGeocodeScreen({super.key});

  @override
  State<TestReverseGeocodeScreen> createState() =>
      _TestReverseGeocodeScreenState();
}

class _TestReverseGeocodeScreenState extends State<TestReverseGeocodeScreen> {
  String? _address;
  bool _isLoading = false;

  Future<void> _testReverseGeocode() async {
    setState(() {
      _isLoading = true;
      _address = null;
    });

    try {
      // Test with coordinates for Empire State Building
      final address = await ReverseGeocodeService.reverseGeocode(
        40.748817,
        -73.985428,
      );

      setState(() {
        _address = address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _address = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reverse Geocode Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testReverseGeocode,
              child: Text(_isLoading ? 'Testing...' : 'Test Reverse Geocode'),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_address != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Address:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_address!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
