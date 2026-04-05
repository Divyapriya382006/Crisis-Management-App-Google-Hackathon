// lib/core/network/network_checker.dart
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors device network connectivity.
/// Subscribe to [onConnectivityChanged] to react to offline/online transitions.
class NetworkChecker {
  static final NetworkChecker _instance = NetworkChecker._();
  NetworkChecker._();
  static NetworkChecker get instance => _instance;

  final Connectivity _connectivity = Connectivity();

  /// Stream of [bool] — true = connected, false = offline
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(
        (result) => result != ConnectivityResult.none,
      );

  /// One-time check for current connectivity status
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
