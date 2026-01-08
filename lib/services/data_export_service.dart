import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

import '../models/envelope.dart';
import '../models/transaction.dart';
import '../models/scheduled_payment.dart';
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

    // Use getAllGroupsAsync to read from Hive (works in both solo and workspace mode)
    final groups = await _groupRepo.getAllGroupsAsync();

    final accounts = await _accountRepo.getAllAccounts(); // Fetch all accounts

    final groupMap = {for (var group in groups) group.id: group.name};
    final envelopeMap = {for (var envelope in envelopes) envelope.id: envelope.name};
    final accountMap = {for (var acc in accounts) acc.id: acc}; // Map for account lookup

    _createSummarySheet(excel, envelopes, accounts);
    _createEnvelopesSheet(excel, envelopes, groupMap, accountMap); // Pass accountMap
    _createTransactionsSheet(excel, transactions, envelopeMap);
    _createScheduledPaymentsSheet(excel, scheduledPayments);
    _createAccountsSheet(excel, accounts); // New sheet creation

    // Remove the default 'Sheet1' that gets created automatically
    excel.delete('Sheet1');

    // Save to Documents directory instead of temporary directory
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now();
    final formattedDate = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    final filePath =
        '${directory.path}/stuffrite_export_$formattedDate.xlsx';
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

  void _createSummarySheet(Excel excel, List<Envelope> envelopes, List<Account> accounts) {
    final sheet = excel['Summary'];
    final headers = ['Metric', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }

    // Calculate total envelope balance (assigned funds)
    final totalEnvelopeBalance = envelopes.fold<double>(0.0, (sum, env) => sum + env.currentAmount);

    // Calculate total account balance
    final totalAccountBalance = accounts.fold<double>(0.0, (sum, acc) => sum + acc.currentBalance);

    // Available balance = total in accounts - total assigned to envelopes
    final totalAvailable = totalAccountBalance - totalEnvelopeBalance;

    // Net worth = all account balances (includes credit card debt as negative)
    final netWorth = totalAccountBalance;

    sheet.appendRow([TextCellValue('Total Net Worth'), DoubleCellValue(netWorth)]);
    sheet.appendRow([TextCellValue('Total in Accounts'), DoubleCellValue(totalAccountBalance)]);
    sheet.appendRow([TextCellValue('Total Assigned to Envelopes'), DoubleCellValue(totalEnvelopeBalance)]);
    sheet.appendRow([TextCellValue('Available to Assign'), DoubleCellValue(totalAvailable)]);
    sheet.appendRow([TextCellValue('Export Date'), TextCellValue(DateTime.now().toIso8601String())]);
  }

  void _createEnvelopesSheet(Excel excel, List<Envelope> envelopes, Map<String?, String> groupMap, Map<String, Account> accountMap) {
    final sheet = excel['Envelopes'];
    final headers = [
      'Name', 'Current Balance', 'Target Amount', 'Progress %', 'Group Name',
      'Icon', 'Is Shared', 'Auto-Fill Settings', 'Linked Account Name'
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
      final autoFillSettings = envelope.cashFlowEnabled
          ? 'Enabled (${envelope.cashFlowAmount ?? 0.0})'
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
      'Date', 'Amount', 'Type', 'Envelope Name', 'Description', 'User ID'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }


    for (final tx in transactions) {
      String typeLabel;
      switch (tx.type) {
        case TransactionType.deposit:
          typeLabel = 'Deposit';
          break;
        case TransactionType.withdrawal:
          typeLabel = 'Withdrawal';
          break;
        case TransactionType.scheduledPayment:
          typeLabel = 'Scheduled Payment';
          break;
        case TransactionType.transfer:
          typeLabel = 'Transfer';
          break;
      }

      sheet.appendRow([
        TextCellValue(tx.date.toIso8601String()),
        DoubleCellValue(tx.amount),
        TextCellValue(typeLabel),
        TextCellValue(envelopeMap[tx.envelopeId] ?? 'N/A'),
        TextCellValue(tx.description),
        TextCellValue(tx.userId),
      ]);
    }
  }

  void _createScheduledPaymentsSheet(Excel excel, List<ScheduledPayment> payments) {
    final sheet = excel['Scheduled Payments'];
    final headers = ['Name', 'Amount', 'Frequency', 'Next Due Date', 'Auto-Pay Enabled'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(bold: true);
    }


    for (final payment in payments) {
      final frequency = 'Every ${payment.frequencyValue} ${payment.frequencyUnit.name}';
      sheet.appendRow([
        TextCellValue(payment.name),
        DoubleCellValue(payment.amount),
        TextCellValue(frequency),
        TextCellValue(payment.nextDueDate.toIso8601String()),
        TextCellValue(payment.isAutomatic.toString()),
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
              onTap: () async {
                Navigator.of(ctx).pop();
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(filePath)],
                    text: 'Stuffrite Data Export',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open File'),
              onTap: () {
                Navigator.of(ctx).pop();
                OpenFile.open(filePath);
              },
            ),
          ],
        ),
      ),
    );
  }
}
