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
    final autoFillEnvelopes = await envelopeRepo.getAutoFillEnvelopes();

    final totalAutoFill = autoFillEnvelopes.fold(
      0.0,
      (sum, e) => sum + (e.autoFillAmount ?? 0.0),
    );

    debugPrint('[PayDay] Budget: £$budgetAmount, Auto-fill: £$totalAutoFill');

    // Process auto-fills (magic money appears!)
    int successCount = 0;
    for (final envelope in autoFillEnvelopes) {
      try {
        await envelopeRepo.addMoney(
          envelope.id,
          envelope.autoFillAmount ?? 0.0,
          description: 'Pay Day Auto-Fill',
        );
        successCount++;
        debugPrint('[PayDay] ✅ ${envelope.name}: +£${envelope.autoFillAmount}');
      } catch (e) {
        debugPrint('[PayDay] ❌ ${envelope.name} failed: $e');
      }
    }

    // Update next pay date
    await payDayService.updateNextPayDate();

    return PayDayResult.success(
      mode: 'Budget Mode',
      envelopesFilled: successCount,
      totalAllocated: totalAutoFill,
      budgetAmount: budgetAmount,
      remaining: budgetAmount - totalAutoFill,
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

    // 1. DEPOSIT PAY INTO DEFAULT ACCOUNT
    await accountRepo.deposit(
      defaultAccount.id,
      payAmount,
      description: 'Pay Day Deposit',
    );
    debugPrint('[PayDay] 💰 Deposited £$payAmount into ${defaultAccount.name}');

    // 2. AUTO-FILL ENVELOPES LINKED TO DEFAULT ACCOUNT
    final defaultEnvelopes = await envelopeRepo.getEnvelopesLinkedToAccount(defaultAccount.id).first;
    final defaultAutoFill = defaultEnvelopes.where((e) => e.autoFillEnabled).toList();

    int envelopesFilled = 0;
    double totalEnvelopeFill = 0;

    for (final envelope in defaultAutoFill) {
      final currentAccount = await accountRepo.getAccount(defaultAccount.id);
      final fillAmount = envelope.autoFillAmount ?? 0.0;

      if (currentAccount!.currentBalance >= fillAmount) {
        await accountRepo.withdraw(
          defaultAccount.id,
          fillAmount,
          description: 'Auto-fill ${envelope.name}',
        );

        await envelopeRepo.addMoney(
          envelope.id,
          fillAmount,
          description: 'Pay Day Auto-Fill',
        );

        envelopesFilled++;
        totalEnvelopeFill += fillAmount;
        debugPrint('[PayDay] ✅ ${envelope.name}: +£$fillAmount');
      } else {
        warnings.add('Skipped ${envelope.name} - insufficient funds in ${defaultAccount.name}');
        debugPrint('[PayDay] ⚠️ Skipped ${envelope.name}');
      }
    }

    // 3. ACCOUNT-TO-ACCOUNT AUTO-FILLS (Savings, Credit Cards)
    final otherAccounts = await accountRepo.getAccountsWithAutoFill();
    final accountsToFill = otherAccounts.where((a) => a.id != defaultAccount.id).toList();

    int accountsFilled = 0;
    double totalAccountFill = 0;

    for (final account in accountsToFill) {
      final currentBalance = await accountRepo.getAccount(defaultAccount.id);
      final fillAmount = account.payDayAutoFillAmount ?? 0.0;

      if (currentBalance!.currentBalance >= fillAmount) {
        await accountRepo.transfer(
          defaultAccount.id,
          account.id,
          fillAmount,
          description: 'Auto-transfer to ${account.name}',
        );

        accountsFilled++;
        totalAccountFill += fillAmount;
        debugPrint('[PayDay] 💸 ${account.name}: +£$fillAmount');

        // 4. AUTO-FILL THIS ACCOUNT'S ENVELOPES
        final accountEnvelopes = await envelopeRepo.getEnvelopesLinkedToAccount(account.id).first;
        final accountAutoFill = accountEnvelopes.where((e) => e.autoFillEnabled).toList();

        for (final envelope in accountAutoFill) {
          final accountBalance = await accountRepo.getAccount(account.id);
          final envelopeFillAmount = envelope.autoFillAmount ?? 0.0;

          if (accountBalance!.currentBalance >= envelopeFillAmount) {
            await accountRepo.withdraw(
              account.id,
              envelopeFillAmount,
              description: 'Auto-fill ${envelope.name}',
            );

            await envelopeRepo.addMoney(
              envelope.id,
              envelopeFillAmount,
              description: 'Pay Day Auto-Fill',
            );

            envelopesFilled++;
            totalEnvelopeFill += envelopeFillAmount;
            debugPrint('[PayDay] ✅ ${envelope.name} (from ${account.name}): +£$envelopeFillAmount');
          } else {
            warnings.add('Skipped ${envelope.name} - insufficient funds in ${account.name}');
          }
        }
      } else {
        warnings.add('Skipped transfer to ${account.name} - insufficient funds');
      }
    }

    // 5. UPDATE NEXT PAY DATE
    await payDayService.updateNextPayDate();

    // 6. GET FINAL BALANCE
    final finalDefaultAccount = await accountRepo.getAccount(defaultAccount.id);

    return PayDayResult.success(
      mode: 'Account Mirror Mode',
      envelopesFilled: envelopesFilled,
      accountsFilled: accountsFilled,
      totalAllocated: totalEnvelopeFill + totalAccountFill,
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
