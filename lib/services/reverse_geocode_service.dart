import 'dart:convert';
import 'package:http/http.dart' as http;

class ReverseGeocodeService {
  // Using LocationIQ API for reverse geocoding
  static const String _baseUrl = 'https://us1.locationiq.com/v1/reverse.php';

  // This is a public demo key. In production, this should be moved to backend.
  static const String _apiKey = 'pk.cb86e99650036bef1474ebdb7586f405';

  /// Reverse geocode coordinates to get human-readable address
  static Future<String?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?key=$_apiKey&lat=$latitude&lon=$longitude&format=json',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract address components
        final address = data['display_name'];
        if (address != null && address.isNotEmpty) {
          return address;
        }

        // Fallback to constructing address from components
        final addressComponents = data['address'] as Map<String, dynamic>?;
        if (addressComponents != null) {
          final components = [
            addressComponents['house_number'],
            addressComponents['road'],
            addressComponents['suburb'],
            addressComponents['city'] ?? addressComponents['town'],
            addressComponents['state'],
            addressComponents['postcode'],
            addressComponents['country'],
          ].where((component) => component != null).join(', ');

          return components.isNotEmpty ? components : 'Address not found';
        }
      }

      return 'Address not found';
    } catch (e) {
      print('Reverse geocoding error: $e');
      return 'Unable to retrieve address';
    }
  }
}
