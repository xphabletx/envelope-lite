# Manual Database Maintenance

Perform these checks monthly in the Firebase Console.

## 1. Clean Orphaned Workspaces
*Go to Firestore > workspaces collection*
1. Look for documents where the `members` map is empty `{}`.
2. Or, where all members are set to `false`.
3. Delete the document manually.

## 2. Delete Legacy Data
*Go to Firestore > artifacts collection*
1. If this collection exists and contains data from Nov 2025, delete the entire collection.

## 3. Monitor Scheduled Payments
*Go to Firestore > scheduled_payments*
1. Check for documents where `nextOccurrence` is significantly in the past (e.g., > 1 month).
2. This indicates a user who churned (deleted app without deleting account).
3. (Optional) Delete these documents to save storage space.