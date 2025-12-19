// lib/providers/workspace_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that manages the current workspace ID and notifies listeners when it changes.
/// This allows the app to rebuild the HomeScreen with a new EnvelopeRepo when the workspace changes.
class WorkspaceProvider extends ChangeNotifier {
  String? _workspaceId;

  WorkspaceProvider({String? initialWorkspaceId}) : _workspaceId = initialWorkspaceId;

  String? get workspaceId => _workspaceId;

  /// Updates the workspace ID and notifies all listeners.
  /// This should be called when the user joins, creates, or leaves a workspace.
  Future<void> setWorkspaceId(String? newWorkspaceId) async {
    if (_workspaceId != newWorkspaceId) {
      _workspaceId = newWorkspaceId;

      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (newWorkspaceId != null) {
        await prefs.setString('active_workspace_id', newWorkspaceId);
      } else {
        await prefs.remove('active_workspace_id');
      }

      // Notify listeners to rebuild with new workspace
      notifyListeners();
    }
  }

  /// Loads the workspace ID from SharedPreferences
  static Future<String?> loadWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_workspace_id');
  }
}
