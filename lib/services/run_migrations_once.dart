// lib/services/run_migrations_once.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Removed - migration_manager.dart no longer exists
// import 'migration_manager.dart';

/// Safe to call on every app start and after sign-in.
/// - If no user is signed in, it returns immediately.
/// - It only runs once per (buildNumber + userId) on this device.
///
/// NOTE: Migration functionality has been removed
Future<void> runMigrationsOncePerBuild({
  required FirebaseFirestore db,
  String? explicitUid,
}) async {
  // Migration functionality removed - MigrationManager no longer exists
  // Keeping this function stub for backward compatibility
  return;
}
