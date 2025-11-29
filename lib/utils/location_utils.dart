import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class LocationUtils {
  /// Check and request location permissions
  static Future<bool> requestLocationPermission(BuildContext context) async {
    // Check current permission status
    var permission = await Permission.location.status;

    // If permission is denied or restricted, request it
    if (permission.isDenied || permission.isRestricted) {
      permission = await Permission.location.request();

      // If still denied, show explanation and option to open settings
      if (permission.isDenied || permission.isPermanentlyDenied) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'This app needs location access to mark attendance. Please enable location permission in settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
          // Give user time to change settings
          await Future.delayed(const Duration(seconds: 2));
          // Check permission again
          permission = await Permission.location.status;
        }
      }
    }

    return permission.isGranted;
  }

  /// Check if location services are enabled and prompt to enable if not
  static Future<bool> checkAndEnableLocationServices(
    BuildContext context,
  ) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // Show dialog to enable location services
      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Location Services'),
          content: const Text(
            'Location services are turned off. Please enable location services to mark attendance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await Geolocator.openLocationSettings();
                // Give user time to enable location
                await Future.delayed(const Duration(seconds: 2));
              },
              child: const Text('Enable Location'),
            ),
          ],
        ),
      );

      if (shouldEnable == true) {
        // Check if location is now enabled
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
    }

    return serviceEnabled;
  }

  /// Get current location with proper error handling
  static Future<Position?> getCurrentLocation(BuildContext context) async {
    try {
      // First check permissions
      final hasPermission = await requestLocationPermission(context);
      if (!hasPermission) {
        return null;
      }

      // Then check location services
      final isLocationEnabled = await checkAndEnableLocationServices(context);
      if (!isLocationEnabled) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      // Handle specific errors
      if (e is LocationServiceDisabledException) {
        // Show message about disabled location services
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them to continue.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else if (e is PermissionDeniedException) {
        // Show message about denied permissions
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. Please grant permission to continue.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Show generic error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Get location with automatic GPS enabling
  static Future<Position?> getLocationWithAutoEnable(
    BuildContext context,
  ) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        // Try to automatically open location settings
        await Geolocator.openLocationSettings();
        // Wait a bit for user to enable
        await Future.delayed(const Duration(seconds: 3));
        // Check again
        serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (!serviceEnabled) {
          // If still not enabled, show manual prompt
          return await getCurrentLocation(context);
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      // Handle errors
      print('Error getting location: $e');
      return null;
    }
  }
}
