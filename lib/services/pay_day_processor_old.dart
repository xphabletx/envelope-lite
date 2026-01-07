// ============================================================================
// ARCHIVED FILE - DO NOT USE
// This file is preserved for reference only from commit 493c427.
// It is NOT wired into the application and has broken dependencies.
// See README_OLD_FILES.md for details.
// ============================================================================

// lib/services/pay_day_processor.dart
import 'package:flutter/foundation.dart';
import './envelope_repo.dart';
import './account_repo.dart';
import './pay_day_settings_service.dart';

class PayDayProcessor {
  final EnvelopeRepo envelopeRepo;
  final AccountRepo accountRepo;
  final PayDaySettingsService payDayService;

  PayDayProcessor({
    required this.envelopeRepo,
    required this.accountRepo,
    required this.payDayService,
  });

  // Determine which mode we're in
  Future<bool> isAccountMirrorMode() async {
    final settings = await payDayService.getSettings();
    return settings?.defaultAccountId != null;
  }

  // Process pay day (delegates to correct mode)
  Future<PayDayResult> processPayDay() async {
    final isAccountMode = await isAccountMirrorMode();

    if (isAccountMode) {
      return await _processAccountMirrorMode();
    } else {
      return await _processBudgetMode();
    }
  }

  // BUDGET MODE: Virtual allocation (magic money)
  Future<PayDayResult> _processBudgetMode() async {
    debugPrint('[PayDay] Processing in BUDGET MODE');

    final settings = await payDayService.getSettings();
    if (settings == null) {
      return PayDayResult.error('No pay day settings found');
    }

    final budgetAmount = settings.expectedPayAmount ?? 0.0;
    final cashFlowEnvelopes = await envelopeRepo.getCashFlowEnvelopes();

    final totalCashFlow = cashFlowEnvelopes.fold(
      0.0,
      (sum, e) => sum + (e.cashFlowAmount ?? 0.0),
    );

    debugPrint('[PayDay] Budget: £$budgetAmount, Cash Flow: £$totalCashFlow');

    // Process cash flows (magic money appears!)
    // In Budget Mode, this is still EXTERNAL (virtual income from outside)
    int successCount = 0;
    for (final envelope in cashFlowEnvelopes) {
      try {
        await envelopeRepo.addMoney(
          envelope.id,
          envelope.cashFlowAmount ?? 0.0,
          description: 'Pay Day Cash Flow',
          // EXTERNAL because it's virtual income (no real account involved)
        );
        successCount++;
        debugPrint('[PayDay] ✅ ${envelope.name}: +£${envelope.cashFlowAmount}');
      } catch (e) {
        debugPrint('[PayDay] ❌ ${envelope.name} failed: $e');
      }
    }

    // Update next pay date
    await payDayService.updateNextPayDate();

    return PayDayResult.success(
      mode: 'Budget Mode',
      envelopesFilled: successCount,
      totalAllocated: totalCashFlow,
      budgetAmount: budgetAmount,
      remaining: budgetAmount - totalCashFlow,
    );
  }

  // ACCOUNT MIRROR MODE: Real account tracking
  Future<PayDayResult> _processAccountMirrorMode() async {
    debugPrint('[PayDay] Processing in ACCOUNT MIRROR MODE');

    final settings = await payDayService.getSettings();
    if (settings == null || settings.defaultAccountId == null) {
      return PayDayResult.error('No default account set');
    }

    final defaultAccount = await accountRepo.getAccount(settings.defaultAccountId!);
    if (defaultAccount == null) {
      return PayDayResult.error('Default account not found');
    }

    final payAmount = settings.expectedPayAmount ?? 0.0;
    final warnings = <String>[];

    // 1. DEPOSIT PAY INTO DEFAULT ACCOUNT (EXTERNAL - income from employer)
    await accountRepo.deposit(
      defaultAccount.id,
      payAmount,
      description: 'Pay Day Deposit',
    );
    debugPrint('[PayDay] 💰 Deposited £$payAmount into ${defaultAccount.name}');

    // 2. CASH FLOW ENVELOPES LINKED TO DEFAULT ACCOUNT
    final defaultEnvelopes = await envelopeRepo.getEnvelopesLinkedToAccount(defaultAccount.id).first;
    final defaultCashFlow = defaultEnvelopes.where((e) => e.cashFlowEnabled).toList();

    int envelopesFilled = 0;
    double totalEnvelopeFill = 0;

    for (final envelope in defaultCashFlow) {
      final currentAccount = await accountRepo.getAccount(defaultAccount.id);
      final fillAmount = envelope.cashFlowAmount ?? 0.0;

      if (currentAccount!.currentBalance >= fillAmount) {
        // INTERNAL transfer: Account → Envelope (money stays inside the system)
        await accountRepo.transferToEnvelope(
          accountId: defaultAccount.id,
          envelopeId: envelope.id,
          amount: fillAmount,
          description: 'Cash Flow',
          date: DateTime.now(),
          envelopeRepo: envelopeRepo,
        );

        envelopesFilled++;
        totalEnvelopeFill += fillAmount;
        debugPrint('[PayDay] ✅ ${envelope.name}: +£$fillAmount (INTERNAL transfer)');
      } else {
        warnings.add('Skipped ${envelope.name} - insufficient funds in ${defaultAccount.name}');
        debugPrint('[PayDay] ⚠️ Skipped ${envelope.name}');
      }
    }

    // 3. Process envelopes linked to other accounts (no account-to-account transfers needed)
    final allAccounts = await accountRepo.getAllAccounts();
    final otherAccounts = allAccounts.where((a) => a.id != defaultAccount.id).toList();

    for (final account in otherAccounts) {
      // Process cash flow envelopes for this account
      final accountEnvelopes = await envelopeRepo.getEnvelopesLinkedToAccount(account.id).first;
      final accountCashFlow = accountEnvelopes.where((e) => e.cashFlowEnabled).toList();

      for (final envelope in accountCashFlow) {
        final accountBalance = await accountRepo.getAccount(account.id);
        final envelopeFillAmount = envelope.cashFlowAmount ?? 0.0;

        if (accountBalance!.currentBalance >= envelopeFillAmount) {
          // INTERNAL transfer: Account → Envelope (money stays inside the system)
          await accountRepo.transferToEnvelope(
            accountId: account.id,
            envelopeId: envelope.id,
            amount: envelopeFillAmount,
            description: 'Cash Flow',
            date: DateTime.now(),
            envelopeRepo: envelopeRepo,
          );

          envelopesFilled++;
          totalEnvelopeFill += envelopeFillAmount;
          debugPrint('[PayDay] ✅ ${envelope.name} (from ${account.name}): +£$envelopeFillAmount (INTERNAL transfer)');
        } else {
          warnings.add('Skipped ${envelope.name} - insufficient funds in ${account.name}');
        }
      }
    }

    // 5. UPDATE NEXT PAY DATE
    await payDayService.updateNextPayDate();

    // 6. GET FINAL BALANCE
    final finalDefaultAccount = await accountRepo.getAccount(defaultAccount.id);

    return PayDayResult.success(
      mode: 'Account Mirror Mode',
      envelopesFilled: envelopesFilled,
      accountsFilled: 0,
      totalAllocated: totalEnvelopeFill,
      payAmount: payAmount,
      remaining: finalDefaultAccount!.currentBalance,
      warnings: warnings,
    );
  }
}

// Result class
class PayDayResult {
  final bool success;
  final String? error;
  final String mode;
  final int envelopesFilled;
  final int accountsFilled;
  final double totalAllocated;
  final double? budgetAmount;
  final double? payAmount;
  final double remaining;
  final List<String> warnings;

  PayDayResult.success({
    required this.mode,
    required this.envelopesFilled,
    this.accountsFilled = 0,
    required this.totalAllocated,
    this.budgetAmount,
    this.payAmount,
    required this.remaining,
    this.warnings = const [],
  })  : success = true,
        error = null;

  PayDayResult.error(this.error)
      : success = false,
        mode = '',
        envelopesFilled = 0,
        accountsFilled = 0,
        totalAllocated = 0,
        budgetAmount = null,
        payAmount = null,
        remaining = 0,
        warnings = const [];
}
