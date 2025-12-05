// lib/services/workspace_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper functions to complement existing WorkspaceGate
class WorkspaceHelper {
  static final _db = FirebaseFirestore.instance;

  /// Get active workspace ID from SharedPreferences
  static Future<String?> getActiveWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_workspace_id');
  }

  /// Set active workspace ID
  static Future<void> setActiveWorkspaceId(String? workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (workspaceId == null) {
      await prefs.remove('last_workspace_id');
      await prefs.remove('last_workspace_name');
    } else {
      await prefs.setString('last_workspace_id', workspaceId);
    }
  }

  /// Get show partner envelopes preference (default: true)
  static Future<bool> getShowPartnerEnvelopes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('show_partner_envelopes') ?? true;
  }

  /// Set show partner envelopes preference
  static Future<void> setShowPartnerEnvelopes(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_partner_envelopes', show);
  }

  /// Get show partner binders preference (default: true)
  static Future<bool> getShowPartnerBinders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('show_partner_binders') ?? true;
  }

  /// Set show partner binders preference
  static Future<void> setShowPartnerBinders(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_partner_binders', show);
  }

  /// Get partner user IDs in workspace (excluding current user)
  static Future<List<String>> getPartnerUserIds(
    String workspaceId,
    String currentUserId,
  ) async {
    try {
      final doc = await _db.collection('workspaces').doc(workspaceId).get();
      if (!doc.exists) return [];

      final data = doc.data();
      final members = (data?['members'] as Map<String, dynamic>?) ?? {};

      return members.keys.where((id) => id != currentUserId).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get display name or nickname for a user
  static Future<String> getUserDisplayName(
    String userId,
    String currentUserId,
  ) async {
    try {
      // First check if current user has a nickname for this person
      final currentUserDoc = await _db
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserData = currentUserDoc.data();
      final nicknames =
          (currentUserData?['nicknames'] as Map<String, dynamic>?) ?? {};
      final nickname = (nicknames[userId] as String?)?.trim();

      if (nickname != null && nickname.isNotEmpty) {
        return nickname;
      }

      // Fall back to their display name
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data();
      return (userData?['displayName'] as String?) ??
          (userData?['email'] as String?) ??
          'Partner';
    } catch (_) {
      return 'Partner';
    }
  }

  /// Leave workspace (removes member, clears active workspace if needed)
  static Future<void> leaveWorkspace(
    String workspaceId,
    String currentUserId,
  ) async {
    await _db.collection('workspaces').doc(workspaceId).update({
      'members.$currentUserId': FieldValue.delete(),
    });

    // Clear active workspace
    final activeId = await getActiveWorkspaceId();
    if (activeId == workspaceId) {
      await setActiveWorkspaceId(null);
    }
  }

  /// Get workspace display name
  static Future<String> getWorkspaceName(String workspaceId) async {
    try {
      final doc = await _db.collection('workspaces').doc(workspaceId).get();
      final data = doc.data();
      final displayName = (data?['displayName'] as String?)?.trim() ?? '';
      final joinCode =
          (data?['name'] ?? data?['joinCode']) as String? ?? workspaceId;

      return displayName.isEmpty ? joinCode : '$joinCode ($displayName)';
    } catch (_) {
      return workspaceId;
    }
  }
}
