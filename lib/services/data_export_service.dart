import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

import '../models/envelope.dart';
import '../models/transaction.dart';
import '../models/scheduled_payment.dart';
import '../models/envelope_group.dart';
import '../models/account.dart'; // New import for Account model
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart'; // New import for AccountRepo
import '../services/scheduled_payment_repo.dart';

class DataExportService {
  final EnvelopeRepo _envelopeRepo;
  final GroupRepo _groupRepo;
  final ScheduledPaymentRepo _scheduledPaymentRepo;
  final AccountRepo _accountRepo; // New dependency

  DataExportService({
    required EnvelopeRepo envelopeRepo,
    required GroupRepo groupRepo,
    required ScheduledPaymentRepo scheduledPaymentRepo,
    required AccountRepo accountRepo, // New parameter
  })  : _envelopeRepo = envelopeRepo,
        _groupRepo = groupRepo,
        _scheduledPaymentRepo = scheduledPaymentRepo,
        _accountRepo = accountRepo; // New assignment

  Future<String> generateExcelFile() async {
    final excel = Excel.createExcel();

    // Fetch all data
    final envelopes = await _envelopeRepo.getAllEnvelopes();
    final transactions = await _envelopeRepo.getAllTransactions();
    final scheduledPayments = await _scheduledPaymentRepo.getAllScheduledPayments();
    
    final groupsSnapshot = await _groupRepo.groupsCol().get();
    final groups = groupsSnapshot.docs
        .map((doc) => EnvelopeGroup.fromFirestore(doc))
        .toList();

    final accounts = await _accountRepo.getAllAccounts(); // Fetch all accounts

    final groupMap = {for (var group in groups) group.id: group.name};
    final envelopeMap = {for (var envelope in envelopes) envelope.id: envelope.name};
    final accountMap = {for (var acc in accounts) acc.id: acc}; // Map for account lookup

    _createSummarySheet(excel, envelopes);
    _createEnvelopesSheet(excel, envelopes, groupMap, accountMap); // Pass accountMap
    _createTransactionsSheet(excel, transactions, envelopeMap);
    _createScheduledPaymentsSheet(excel, scheduledPayments);
    _createAccountsSheet(excel, accounts); // New sheet creation

    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/envelope_lite_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.save();

    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      return filePath;
    } else {
      throw Exception('Failed to save Excel file.');
    }
  }

  void _createSummarySheet(Excel excel, List<Envelope> envelopes) {
    final sheet = excel['Summary'];
    final headers = ['Metric', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }

    final totalNetWorth = envelopes.fold<double>(0.0, (sum, env) => sum + env.currentAmount);
    // Assuming 'Allocated' is the sum of all envelope balances.
    // 'Unallocated' would depend on a total budget figure not provided here.
    final totalAllocated = totalNetWorth;
    const totalUnallocated = 0.0; 

    sheet.appendRow([TextCellValue('Total Net Worth'), DoubleCellValue(totalNetWorth)]);
    sheet.appendRow([TextCellValue('Total Allocated'), DoubleCellValue(totalAllocated)]);
    sheet.appendRow([TextCellValue('Total Unallocated'), DoubleCellValue(totalUnallocated)]);
    sheet.appendRow([TextCellValue('Export Date'), TextCellValue(DateTime.now().toIso8601String())]);
  }

  void _createEnvelopesSheet(Excel excel, List<Envelope> envelopes, Map<String?, String> groupMap, Map<String, Account> accountMap) {
    final sheet = excel['Envelopes'];
    final headers = [
      'Name', 'Balance', 'Target Amount', 'Progress %', 'Group Name',
      'Icon (emoji/text)', 'Is Shared', 'Auto-Fill Settings', 'Linked Account Name' // New header
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }


    for (final envelope in envelopes) {
      final progress = ((envelope.targetAmount ?? 0) > 0)
          ? (envelope.currentAmount / envelope.targetAmount! * 100)
          : 0.0;
      final autoFillSettings = envelope.autoFillEnabled 
          ? 'Enabled: ${envelope.autoFillAmount ?? 0.0}' 
          : 'Disabled';
      
      final linkedAccountName = envelope.linkedAccountId != null
          ? accountMap[envelope.linkedAccountId]?.name ?? 'N/A'
          : 'N/A';

      sheet.appendRow([
        TextCellValue(envelope.name),
        DoubleCellValue(envelope.currentAmount),
        DoubleCellValue(envelope.targetAmount ?? 0.0),
        DoubleCellValue(progress),
        TextCellValue(groupMap[envelope.groupId] ?? 'N/A'),
        TextCellValue(envelope.iconValue ?? envelope.emoji ?? 'N/A'),
        TextCellValue(envelope.isShared.toString()),
        TextCellValue(autoFillSettings),
        TextCellValue(linkedAccountName), // New cell
      ]);
    }
  }

  void _createTransactionsSheet(Excel excel, List<Transaction> transactions, Map<String, String> envelopeMap) {
    final sheet = excel['Transactions'];
    final headers = [
      'Date', 'Amount', 'Type', 'Envelope Name', 'Description/Note', 'Who made it (User Name)'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }


    for (final tx in transactions) {
      sheet.appendRow([
        TextCellValue(tx.date.toIso8601String()),
        DoubleCellValue(tx.amount),
        TextCellValue(tx.type == TransactionType.deposit ? 'Deposit' : 'Withdrawal'),
        TextCellValue(envelopeMap[tx.envelopeId] ?? 'N/A'),
        TextCellValue(tx.description),
        TextCellValue(tx.userId),
      ]);
    }
  }

  void _createScheduledPaymentsSheet(Excel excel, List<ScheduledPayment> payments) {
    final sheet = excel['Scheduled Payments'];
    final headers = ['Name', 'Amount', 'Frequency', 'Next Due Date', 'Auto-Pay status'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }


    for (final payment in payments) {
      sheet.appendRow([
        TextCellValue(payment.name),
        DoubleCellValue(payment.amount),
        TextCellValue('N/A'), // Placeholder for frequency
        TextCellValue(payment.nextDueDate.toIso8601String()),
        TextCellValue('N/A'), // Placeholder for autoPay
      ]);
    }
  }

  void _createAccountsSheet(Excel excel, List<Account> accounts) async {
    final sheet = excel['Accounts'];
    final headers = [
        'Account Name', 'Current Balance', 'Is Default',
        'Assigned Amount', 'Available Amount', 'Icon'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }

    for (final account in accounts) {
        final assignedAmount = await _accountRepo.getAssignedAmount(account.id);
        final availableAmount = account.currentBalance - assignedAmount;
        
        sheet.appendRow([
            TextCellValue(account.name),
            DoubleCellValue(account.currentBalance),
            TextCellValue(account.isDefault.toString()),
            DoubleCellValue(assignedAmount),
            DoubleCellValue(availableAmount),
            TextCellValue(account.iconValue ?? account.emoji ?? 'N/A'),
        ]);
    }
}

  static Future<void> showExportOptions(BuildContext context, String filePath) {
    return showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share File'),
              onTap: () {
                Navigator.of(ctx).pop();
                Share.shareXFiles([XFile(filePath)], text: 'Envelope Lite Data Export');
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open in Excel/Sheets'),
              onTap: () {
                Navigator.of(ctx).pop();
                OpenFile.open(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to Device'),
              onTap: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                try {
                  final directory = await getApplicationDocumentsDirectory();
                  final fileName = filePath.split('/').last;
                  final newPath = '${directory.path}/$fileName';
                  await File(filePath).copy(newPath);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Saved to Documents: $fileName'),
                      action: SnackBarAction(
                        label: 'Open',
                        onPressed: () => OpenFile.open(newPath),
                      ),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to save file: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
