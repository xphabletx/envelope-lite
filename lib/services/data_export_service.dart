import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/envelope.dart';
import '../models/transaction.dart';
import '../models/scheduled_payment.dart';
import '../models/account.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart';
import '../services/scheduled_payment_repo.dart';
import '../services/pay_day_settings_service.dart';

class DataExportService {
  final EnvelopeRepo _envelopeRepo;
  final GroupRepo _groupRepo;
  final ScheduledPaymentRepo _scheduledPaymentRepo;
  final AccountRepo _accountRepo;
  final PayDaySettingsService _payDaySettingsService;

  DataExportService({
    required EnvelopeRepo envelopeRepo,
    required GroupRepo groupRepo,
    required ScheduledPaymentRepo scheduledPaymentRepo,
    required AccountRepo accountRepo,
    required PayDaySettingsService payDaySettingsService,
  })  : _envelopeRepo = envelopeRepo,
        _groupRepo = groupRepo,
        _scheduledPaymentRepo = scheduledPaymentRepo,
        _accountRepo = accountRepo,
        _payDaySettingsService = payDaySettingsService;

  Future<String> generateExcelFile() async {
    final excel = Excel.createExcel();

    // Fetch all data - IMPORTANT: Filter by current user only (not partner's data)
    // In workspace mode, only export the current user's own data for privacy
    final allEnvelopes = await _envelopeRepo.envelopesStream(showPartnerEnvelopes: false).first;
    final envelopes = allEnvelopes
        .where((e) => e.userId == _envelopeRepo.currentUserId)
        .toList();

    final allTransactions = await _envelopeRepo.getAllTransactions();
    final transactions = allTransactions
        .where((tx) => tx.userId == _envelopeRepo.currentUserId)
        .toList();

    final scheduledPayments = await _scheduledPaymentRepo.getAllScheduledPayments();

    // Use getAllGroupsAsync to read from Hive (works in both solo and workspace mode)
    // Groups are always local-only, already filtered by userId
    final groups = await _groupRepo.getAllGroupsAsync();

    // Accounts are already filtered by userId in getAllAccounts()
    final accounts = await _accountRepo.getAllAccounts();

    // Pay day settings
    final payDaySettings = await _payDaySettingsService.getPayDaySettings();

    // Locale settings
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString('currency_code') ?? 'GBP';
    final currencySymbol = _getCurrencySymbol(currencyCode);
    final languageCode = prefs.getString('language_code') ?? 'en';
    final horizonEmoji = prefs.getString('horizon_emoji') ?? prefs.getString('celebration_emoji') ?? '🥰';

    final groupMap = {for (var group in groups) group.id: group.name};
    final envelopeMap = {for (var envelope in envelopes) envelope.id: envelope.name};
    final accountMap = {for (var acc in accounts) acc.id: acc};

    // Create all sheets
    await _createUserProfileSheet(excel, currencyCode, currencySymbol, languageCode, horizonEmoji);
    _createSummarySheet(excel, envelopes, accounts, currencySymbol);
    if (payDaySettings != null) {
      _createPayDaySettingsSheet(excel, payDaySettings, accountMap, currencySymbol);
    }
    _createEnvelopesSheet(excel, envelopes, groupMap, accountMap, currencySymbol);
    _createEnvelopeAnalyticsSheet(excel, envelopes, transactions, currencySymbol);
    _createAccountsSheet(excel, accounts, currencySymbol);
    await _createAccountPerformanceSheet(excel, accounts, envelopes, transactions, currencySymbol);
    _createPortfolioAnalyticsSheet(excel, envelopes, transactions, accounts, currencySymbol);
    _createAutopilotSettingsSheet(excel, envelopes, accountMap, currencySymbol);
    _createHorizonProgressSheet(excel, envelopes, currencySymbol);
    _createTransactionsSheet(excel, transactions, envelopeMap, accountMap, currencySymbol);
    _createScheduledPaymentsSheet(excel, scheduledPayments, currencySymbol);

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

  String _getCurrencySymbol(String code) {
    const currencyMap = {
      'GBP': '£', 'EUR': '€', 'USD': '\$', 'CAD': 'C\$', 'MXN': 'Mex\$',
      'BRL': 'R\$', 'ARS': 'ARS\$', 'JPY': '¥', 'CNY': '¥', 'INR': '₹',
      'AUD': 'A\$', 'NZD': 'NZ\$', 'SGD': 'S\$', 'HKD': 'HK\$', 'KRW': '₩',
      'AED': 'AED', 'SAR': 'SAR', 'ZAR': 'R', 'CHF': 'CHF', 'SEK': 'kr',
      'NOK': 'kr', 'DKK': 'kr', 'PLN': 'zł', 'TRY': '₺',
    };
    return currencyMap[code] ?? code;
  }

  Future<void> _createUserProfileSheet(
    Excel excel,
    String currencyCode,
    String currencySymbol,
    String languageCode,
    String horizonEmoji,
  ) async {
    final sheet = excel['User Profile'];
    final headers = ['Setting', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    sheet.appendRow([TextCellValue('User ID'), TextCellValue(_envelopeRepo.currentUserId)]);
    sheet.appendRow([TextCellValue('Currency Code'), TextCellValue(currencyCode)]);
    sheet.appendRow([TextCellValue('Currency Symbol'), TextCellValue(currencySymbol)]);
    sheet.appendRow([TextCellValue('Language'), TextCellValue(languageCode)]);
    sheet.appendRow([TextCellValue('Horizon Emoji'), TextCellValue(horizonEmoji)]);
    sheet.appendRow([TextCellValue('Export Date'), TextCellValue(DateTime.now().toIso8601String())]);
  }

  void _createSummarySheet(Excel excel, List<Envelope> envelopes, List<Account> accounts, String currencySymbol) {
    final sheet = excel['Summary'];
    final headers = ['Metric', 'Value ($currencySymbol)'];
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
    sheet.appendRow([TextCellValue('Number of Envelopes'), IntCellValue(envelopes.length)]);
    sheet.appendRow([TextCellValue('Number of Accounts'), IntCellValue(accounts.length)]);
  }

  void _createPayDaySettingsSheet(
    Excel excel,
    dynamic payDaySettings,
    Map<String, Account> accountMap,
    String currencySymbol,
  ) {
    final sheet = excel['Pay Day Settings'];
    final headers = ['Setting', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    sheet.appendRow([TextCellValue('Pay Frequency'), TextCellValue(payDaySettings.payFrequency ?? 'N/A')]);
    sheet.appendRow([TextCellValue('Expected Pay Amount ($currencySymbol)'), DoubleCellValue(payDaySettings.expectedPayAmount ?? 0.0)]);
    sheet.appendRow([TextCellValue('Last Pay Amount ($currencySymbol)'), DoubleCellValue(payDaySettings.lastPayAmount ?? 0.0)]);
    sheet.appendRow([TextCellValue('Last Pay Date'), TextCellValue(payDaySettings.lastPayDate?.toIso8601String() ?? 'N/A')]);
    sheet.appendRow([TextCellValue('Next Pay Date'), TextCellValue(payDaySettings.nextPayDate?.toIso8601String() ?? 'N/A')]);
    sheet.appendRow([TextCellValue('Pay Day of Month'), IntCellValue(payDaySettings.payDayOfMonth ?? 0)]);
    sheet.appendRow([TextCellValue('Pay Day of Week'), IntCellValue(payDaySettings.payDayOfWeek ?? 0)]);
    sheet.appendRow([TextCellValue('Adjust for Weekends'), TextCellValue(payDaySettings.adjustForWeekends.toString())]);

    final defaultAccountName = payDaySettings.defaultAccountId != null
        ? accountMap[payDaySettings.defaultAccountId]?.name ?? 'N/A'
        : 'N/A';
    sheet.appendRow([TextCellValue('Default Account'), TextCellValue(defaultAccountName)]);
  }

  void _createEnvelopesSheet(
    Excel excel,
    List<Envelope> envelopes,
    Map<String?, String> groupMap,
    Map<String, Account> accountMap,
    String currencySymbol,
  ) {
    final sheet = excel['Envelopes'];
    final headers = [
      'Name', 'Current Balance ($currencySymbol)', 'Target Amount ($currencySymbol)', 'Progress %',
      'Target Date', 'Group Name', 'Icon', 'Is Shared', 'Cash Flow Enabled',
      'Cash Flow Amount ($currencySymbol)', 'Linked Account', 'Created At', 'Is Debt Envelope',
      'Starting Debt ($currencySymbol)', 'Monthly Payment ($currencySymbol)'
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

      final linkedAccountName = envelope.linkedAccountId != null
          ? accountMap[envelope.linkedAccountId]?.name ?? 'N/A'
          : 'N/A';

      sheet.appendRow([
        TextCellValue(envelope.name),
        DoubleCellValue(envelope.currentAmount),
        DoubleCellValue(envelope.targetAmount ?? 0.0),
        DoubleCellValue(progress),
        TextCellValue(envelope.targetDate?.toIso8601String() ?? 'N/A'),
        TextCellValue(groupMap[envelope.groupId] ?? 'N/A'),
        TextCellValue(envelope.iconValue ?? envelope.emoji ?? 'N/A'),
        TextCellValue(envelope.isShared.toString()),
        TextCellValue(envelope.cashFlowEnabled.toString()),
        DoubleCellValue(envelope.cashFlowAmount ?? 0.0),
        TextCellValue(linkedAccountName),
        TextCellValue(envelope.createdAt?.toIso8601String() ?? 'N/A'),
        TextCellValue(envelope.isDebtEnvelope.toString()),
        DoubleCellValue(envelope.startingDebt ?? 0.0),
        DoubleCellValue(envelope.monthlyPayment ?? 0.0),
      ]);
    }
  }

  void _createEnvelopeAnalyticsSheet(
    Excel excel,
    List<Envelope> envelopes,
    List<Transaction> transactions,
    String currencySymbol,
  ) {
    final sheet = excel['Envelope Analytics'];
    final headers = [
      'Envelope Name', 'Current Balance ($currencySymbol)', 'Total Deposits ($currencySymbol)',
      'Total Withdrawals ($currencySymbol)', 'Net Change ($currencySymbol)', 'Transaction Count',
      'Avg Deposit ($currencySymbol)', 'Avg Withdrawal ($currencySymbol)', 'Last Transaction Date'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    for (final envelope in envelopes) {
      final envTransactions = transactions.where((tx) => tx.envelopeId == envelope.id).toList();

      final deposits = envTransactions.where((tx) =>
        tx.type == TransactionType.deposit ||
        (tx.type == TransactionType.transfer && tx.amount > 0)
      ).toList();

      final withdrawals = envTransactions.where((tx) =>
        tx.type == TransactionType.withdrawal ||
        tx.type == TransactionType.scheduledPayment ||
        (tx.type == TransactionType.transfer && tx.amount < 0)
      ).toList();

      final totalDeposits = deposits.fold<double>(0.0, (sum, tx) => sum + tx.amount.abs());
      final totalWithdrawals = withdrawals.fold<double>(0.0, (sum, tx) => sum + tx.amount.abs());
      final netChange = totalDeposits - totalWithdrawals;

      final avgDeposit = deposits.isEmpty ? 0.0 : totalDeposits / deposits.length;
      final avgWithdrawal = withdrawals.isEmpty ? 0.0 : totalWithdrawals / withdrawals.length;

      envTransactions.sort((a, b) => b.date.compareTo(a.date));
      final lastTxDate = envTransactions.isEmpty ? 'N/A' : envTransactions.first.date.toIso8601String();

      sheet.appendRow([
        TextCellValue(envelope.name),
        DoubleCellValue(envelope.currentAmount),
        DoubleCellValue(totalDeposits),
        DoubleCellValue(totalWithdrawals),
        DoubleCellValue(netChange),
        IntCellValue(envTransactions.length),
        DoubleCellValue(avgDeposit),
        DoubleCellValue(avgWithdrawal),
        TextCellValue(lastTxDate),
      ]);
    }
  }

  void _createAccountsSheet(Excel excel, List<Account> accounts, String currencySymbol) async {
    final sheet = excel['Accounts'];
    final headers = [
      'Account Name', 'Current Balance ($currencySymbol)', 'Is Default',
      'Assigned Amount ($currencySymbol)', 'Available Amount ($currencySymbol)',
      'Icon', 'Created At'
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
        TextCellValue(account.createdAt.toIso8601String()),
      ]);
    }
  }

  Future<void> _createAccountPerformanceSheet(
    Excel excel,
    List<Account> accounts,
    List<Envelope> envelopes,
    List<Transaction> transactions,
    String currencySymbol,
  ) async {
    final sheet = excel['Account Performance'];
    final headers = [
      'Account Name', 'Current Balance ($currencySymbol)', 'Assigned ($currencySymbol)',
      'Available ($currencySymbol)', 'Linked Envelopes', 'Total Envelope Value ($currencySymbol)',
      'Utilization %'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    for (final account in accounts) {
      final linkedEnvelopes = envelopes.where((e) => e.linkedAccountId == account.id).toList();
      final assignedAmount = await _accountRepo.getAssignedAmount(account.id);
      final availableAmount = account.currentBalance - assignedAmount;
      final totalEnvelopeValue = linkedEnvelopes.fold<double>(0.0, (sum, e) => sum + e.currentAmount);
      final utilization = account.currentBalance > 0
          ? (assignedAmount / account.currentBalance * 100)
          : 0.0;

      sheet.appendRow([
        TextCellValue(account.name),
        DoubleCellValue(account.currentBalance),
        DoubleCellValue(assignedAmount),
        DoubleCellValue(availableAmount),
        IntCellValue(linkedEnvelopes.length),
        DoubleCellValue(totalEnvelopeValue),
        DoubleCellValue(utilization),
      ]);
    }
  }

  void _createPortfolioAnalyticsSheet(
    Excel excel,
    List<Envelope> envelopes,
    List<Transaction> transactions,
    List<Account> accounts,
    String currencySymbol,
  ) {
    final sheet = excel['Portfolio Analytics'];
    final headers = ['Metric', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    // Total statistics
    final totalDeposits = transactions
        .where((tx) => tx.type == TransactionType.deposit || (tx.type == TransactionType.transfer && tx.amount > 0))
        .fold<double>(0.0, (sum, tx) => sum + tx.amount.abs());

    final totalWithdrawals = transactions
        .where((tx) => tx.type == TransactionType.withdrawal || tx.type == TransactionType.scheduledPayment || (tx.type == TransactionType.transfer && tx.amount < 0))
        .fold<double>(0.0, (sum, tx) => sum + tx.amount.abs());

    final netCashFlow = totalDeposits - totalWithdrawals;

    final totalAccountBalance = accounts.fold<double>(0.0, (sum, acc) => sum + acc.currentBalance);
    final totalEnvelopeBalance = envelopes.fold<double>(0.0, (sum, env) => sum + env.currentAmount);

    final envelopesWithTargets = envelopes.where((e) => e.targetAmount != null && e.targetAmount! > 0).length;
    final envelopesReachedTarget = envelopes.where((e) =>
      e.targetAmount != null && e.targetAmount! > 0 && e.currentAmount >= e.targetAmount!
    ).length;

    final envelopesWithCashFlow = envelopes.where((e) => e.cashFlowEnabled).length;
    final totalCashFlowPerPeriod = envelopes
        .where((e) => e.cashFlowEnabled)
        .fold<double>(0.0, (sum, e) => sum + (e.cashFlowAmount ?? 0.0));

    sheet.appendRow([TextCellValue('Total Transactions'), IntCellValue(transactions.length)]);
    sheet.appendRow([TextCellValue('Total Deposits ($currencySymbol)'), DoubleCellValue(totalDeposits)]);
    sheet.appendRow([TextCellValue('Total Withdrawals ($currencySymbol)'), DoubleCellValue(totalWithdrawals)]);
    sheet.appendRow([TextCellValue('Net Cash Flow ($currencySymbol)'), DoubleCellValue(netCashFlow)]);
    sheet.appendRow([TextCellValue('Total Account Balance ($currencySymbol)'), DoubleCellValue(totalAccountBalance)]);
    sheet.appendRow([TextCellValue('Total Envelope Balance ($currencySymbol)'), DoubleCellValue(totalEnvelopeBalance)]);
    sheet.appendRow([TextCellValue('Available to Assign ($currencySymbol)'), DoubleCellValue(totalAccountBalance - totalEnvelopeBalance)]);
    sheet.appendRow([TextCellValue('Total Envelopes'), IntCellValue(envelopes.length)]);
    sheet.appendRow([TextCellValue('Envelopes with Targets'), IntCellValue(envelopesWithTargets)]);
    sheet.appendRow([TextCellValue('Envelopes Reached Target'), IntCellValue(envelopesReachedTarget)]);
    sheet.appendRow([TextCellValue('Target Achievement Rate (%)'), DoubleCellValue(envelopesWithTargets > 0 ? (envelopesReachedTarget / envelopesWithTargets * 100) : 0.0)]);
    sheet.appendRow([TextCellValue('Envelopes with Cash Flow'), IntCellValue(envelopesWithCashFlow)]);
    sheet.appendRow([TextCellValue('Total Cash Flow per Period ($currencySymbol)'), DoubleCellValue(totalCashFlowPerPeriod)]);
  }

  void _createAutopilotSettingsSheet(
    Excel excel,
    List<Envelope> envelopes,
    Map<String, Account> accountMap,
    String currencySymbol,
  ) {
    final sheet = excel['Autopilot Settings'];
    final headers = [
      'Envelope Name', 'Autopilot Enabled', 'Amount per Period ($currencySymbol)',
      'Linked Account', 'Has Target', 'Target Amount ($currencySymbol)'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    // Only show envelopes with cash flow enabled (autopilot)
    final autopilotEnvelopes = envelopes.where((e) => e.cashFlowEnabled).toList();

    for (final envelope in autopilotEnvelopes) {
      final linkedAccountName = envelope.linkedAccountId != null
          ? accountMap[envelope.linkedAccountId]?.name ?? 'N/A'
          : 'N/A';

      final hasTarget = envelope.targetAmount != null && envelope.targetAmount! > 0;

      sheet.appendRow([
        TextCellValue(envelope.name),
        TextCellValue('Yes'),
        DoubleCellValue(envelope.cashFlowAmount ?? 0.0),
        TextCellValue(linkedAccountName),
        TextCellValue(hasTarget.toString()),
        DoubleCellValue(envelope.targetAmount ?? 0.0),
      ]);
    }

    if (autopilotEnvelopes.isEmpty) {
      sheet.appendRow([
        TextCellValue('No autopilot envelopes configured'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
    }
  }

  void _createHorizonProgressSheet(
    Excel excel,
    List<Envelope> envelopes,
    String currencySymbol,
  ) {
    final sheet = excel['Horizon Progress'];
    final headers = [
      'Envelope Name', 'Current Amount ($currencySymbol)', 'Target Amount ($currencySymbol)',
      'Progress %', 'Remaining ($currencySymbol)', 'Target Date', 'Days Until Target',
      'Is Complete', 'Is Overdue'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerRow = sheet.row(0);
    for (var cell in headerRow) {
      cell?.cellStyle = CellStyle(bold: true);
    }

    // Only show envelopes with targets
    final targetEnvelopes = envelopes.where((e) =>
      e.targetAmount != null && e.targetAmount! > 0
    ).toList();

    for (final envelope in targetEnvelopes) {
      final targetAmount = envelope.targetAmount ?? 0.0;
      final progress = targetAmount > 0 ? (envelope.currentAmount / targetAmount * 100) : 0.0;
      final remaining = targetAmount - envelope.currentAmount;
      final isComplete = envelope.currentAmount >= targetAmount;

      final daysUntilTarget = envelope.targetDate?.difference(DateTime.now()).inDays;

      final isOverdue = envelope.targetDate != null &&
          DateTime.now().isAfter(envelope.targetDate!) &&
          !isComplete;

      sheet.appendRow([
        TextCellValue(envelope.name),
        DoubleCellValue(envelope.currentAmount),
        DoubleCellValue(targetAmount),
        DoubleCellValue(progress),
        DoubleCellValue(remaining > 0 ? remaining : 0.0),
        TextCellValue(envelope.targetDate?.toIso8601String() ?? 'N/A'),
        TextCellValue(daysUntilTarget?.toString() ?? 'N/A'),
        TextCellValue(isComplete.toString()),
        TextCellValue(isOverdue.toString()),
      ]);
    }

    if (targetEnvelopes.isEmpty) {
      sheet.appendRow([
        TextCellValue('No envelopes with targets'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
    }
  }

  void _createTransactionsSheet(
    Excel excel,
    List<Transaction> transactions,
    Map<String, String> envelopeMap,
    Map<String, Account> accountMap,
    String currencySymbol,
  ) {
    final sheet = excel['Transactions'];
    final headers = [
      'Date', 'Amount ($currencySymbol)', 'Type', 'Envelope Name', 'Description',
      'Transfer Target', 'Is External', 'User ID'
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

      final transferTarget = tx.transferPeerEnvelopeId != null
          ? (envelopeMap[tx.transferPeerEnvelopeId] ?? 'Unknown')
          : 'N/A';

      sheet.appendRow([
        TextCellValue(tx.date.toIso8601String()),
        DoubleCellValue(tx.amount),
        TextCellValue(typeLabel),
        TextCellValue(envelopeMap[tx.envelopeId] ?? 'N/A'),
        TextCellValue(tx.description),
        TextCellValue(transferTarget),
        TextCellValue(tx.impact?.name ?? 'N/A'),
        TextCellValue(tx.userId),
      ]);
    }
  }

  void _createScheduledPaymentsSheet(Excel excel, List<ScheduledPayment> payments, String currencySymbol) {
    final sheet = excel['Scheduled Payments'];
    final headers = [
      'Name', 'Amount ($currencySymbol)', 'Frequency', 'Next Due Date',
      'Auto-Pay Enabled', 'Created At'
    ];
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
        TextCellValue(payment.createdAt.toIso8601String()),
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
