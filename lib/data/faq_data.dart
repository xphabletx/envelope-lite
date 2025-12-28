// lib/data/faq_data.dart

class FAQItem {
  final String emoji;
  final String question;
  final String answer;
  final String? screenshotPath; // Optional screenshot reference
  final List<String> tags; // For search

  const FAQItem({
    required this.emoji,
    required this.question,
    required this.answer,
    this.screenshotPath,
    required this.tags,
  });
}

const List<FAQItem> faqItems = [
  // GETTING STARTED
  FAQItem(
    emoji: '🚀',
    question: 'How do I create my first envelope?',
    answer:
        'Tap the big + button on the home screen! Enter a name, pick an icon, and optionally set a target amount. That\'s it!',
    screenshotPath: 'create_envelope.png',
    tags: ['envelope', 'create', 'start', 'begin', 'new'],
  ),

  FAQItem(
    emoji: '💰',
    question: 'How do I add money to an envelope?',
    answer:
        'Swipe left on any envelope for quick actions, or tap it and use the + button. You can also use the built-in calculator for complex amounts!',
    screenshotPath: 'add_money.png',
    tags: ['envelope', 'money', 'add', 'deposit', 'fund'],
  ),

  // ENVELOPES
  FAQItem(
    emoji: '🎯',
    question: 'What are targets and how do they work?',
    answer:
        'Targets are savings goals! Set an amount and date, and we\'ll show you smart suggestions (daily/weekly/monthly) to reach your goal on time.',
    screenshotPath: 'target_card.png',
    tags: ['target', 'goal', 'savings', 'suggestion'],
  ),

  FAQItem(
    emoji: '📊',
    question: 'How do I see my envelope\'s transaction history?',
    answer:
        'Tap any envelope to view details. You can filter by month using the < > arrows at the top!',
    screenshotPath: 'transaction_history.png',
    tags: ['transaction', 'history', 'envelope', 'filter'],
  ),

  // BINDERS
  FAQItem(
    emoji: '📚',
    question: 'What are binders and why should I use them?',
    answer:
        'Binders group related envelopes together (like "Car" or "Household"). They show combined stats and track ALL transactions from their envelopes in one place!',
    screenshotPath: 'binder_view.png',
    tags: ['binder', 'group', 'organize', 'folder'],
  ),

  FAQItem(
    emoji: '📖',
    question: 'How do I browse my binders?',
    answer:
        'Swipe horizontally! Each binder is like an open book - left page shows envelopes, right page shows stats and controls.',
    screenshotPath: 'binder_swipe.png',
    tags: ['binder', 'swipe', 'navigate', 'browse'],
  ),

  // ACCOUNTS
  FAQItem(
    emoji: '🏦',
    question: 'What\'s the difference between Assigned and Available?',
    answer:
        'Assigned = money you\'ve already put into envelopes. Available = unallocated money in your account. Available is what you can spend freely!',
    screenshotPath: 'account_breakdown.png',
    tags: ['account', 'assigned', 'available', 'balance'],
  ),

  FAQItem(
    emoji: '💳',
    question: 'How do I track credit card debt?',
    answer:
        'Credit cards show as negative balances. We automatically calculate available credit and utilization to help you manage debt!',
    screenshotPath: 'credit_card.png',
    tags: ['credit card', 'debt', 'balance', 'track'],
  ),

  // PAY DAY
  FAQItem(
    emoji: '💸',
    question: 'How does Pay Day work?',
    answer:
        'Enter your pay amount, and we\'ll show you what\'s auto-filled vs what\'s left. You can toggle envelopes on/off before executing. It\'s like magic! ✨',
    screenshotPath: 'pay_day.png',
    tags: ['pay day', 'payday', 'auto fill', 'allocate'],
  ),

  FAQItem(
    emoji: '🤖',
    question: 'What is auto-fill?',
    answer:
        'Enable auto-fill on any envelope to have it fill itself on Pay Day! Set the amount once and forget it. Perfect for bills and recurring expenses.',
    screenshotPath: 'auto_fill.png',
    tags: ['auto fill', 'automatic', 'pay day', 'recurring'],
  ),

  // TIME MACHINE
  FAQItem(
    emoji: '⏰',
    question: 'What is Time Machine?',
    answer:
        'Financial time travel! See exactly where you\'ll be on any future date based on your scheduled payments and pay days. Test "what if" scenarios!',
    screenshotPath: 'time_machine.png',
    tags: ['time machine', 'projection', 'future', 'forecast'],
  ),

  FAQItem(
    emoji: '🔮',
    question: 'Can I change my pay amount in Time Machine?',
    answer:
        'Absolutely! Adjust pay amount, frequency, toggle expenses - see what happens if you get a raise or cut back on spending!',
    screenshotPath: 'time_machine_settings.png',
    tags: ['time machine', 'what if', 'scenario', 'pay'],
  ),

  // WORKSPACE
  FAQItem(
    emoji: '👫',
    question: 'How do workspaces work?',
    answer:
        'Join a workspace to budget with your partner! See each other\'s envelopes in real-time and transfer money between your envelopes!',
    screenshotPath: 'workspace.png',
    tags: ['workspace', 'partner', 'share', 'collaborate'],
  ),

  FAQItem(
    emoji: '🤝',
    question: 'Can I transfer money to my partner\'s envelope?',
    answer:
        'Yes! In workspace mode, use the Transfer action and you\'ll see both your and your partner\'s envelopes. Perfect for shared expenses!',
    screenshotPath: 'partner_transfer.png',
    tags: ['workspace', 'transfer', 'partner', 'share'],
  ),

  // CUSTOMIZATION
  FAQItem(
    emoji: '🎨',
    question: 'Can I change the theme?',
    answer:
        'We have 6 gorgeous themes! Go to Settings → Appearance → Themes. Each theme has 4 binder color variants = 24 combinations!',
    screenshotPath: 'themes.png',
    tags: ['theme', 'appearance', 'color', 'customize'],
  ),

  FAQItem(
    emoji: '✍️',
    question: 'Can I use handwriting fonts?',
    answer:
        'Yes! Try Caveat or Indie Flower for a personal touch. Go to Settings → Appearance → Fonts.',
    screenshotPath: 'fonts.png',
    tags: ['font', 'handwriting', 'appearance', 'customize'],
  ),

  FAQItem(
    emoji: '🏢',
    question: 'Can I use company logos as icons?',
    answer:
        'We have 150+ company logos! When picking an icon, scroll to "Company Logos" and search for your favorite brands.',
    screenshotPath: 'company_logos.png',
    tags: ['icon', 'logo', 'company', 'brand'],
  ),

  // ADVANCED
  FAQItem(
    emoji: '🧮',
    question: 'Is there a built-in calculator?',
    answer:
        'Yes! Look for the calculator chip when entering amounts. Tap it for a full calculator - no need to switch apps!',
    screenshotPath: 'calculator.png',
    tags: ['calculator', 'amount', 'math'],
  ),

  FAQItem(
    emoji: '📤',
    question: 'Can I export my data?',
    answer:
        'Absolutely! Go to Settings → Data & Privacy → Export to Excel. You\'ll get 6 detailed sheets with all your data!',
    screenshotPath: 'export.png',
    tags: ['export', 'excel', 'backup', 'data'],
  ),

  FAQItem(
    emoji: '🔍',
    question: 'How do I sort my envelopes?',
    answer:
        'Tap the sort icon on the home screen! You can sort by name, balance, target, or completion percentage.',
    screenshotPath: 'sort.png',
    tags: ['sort', 'organize', 'filter', 'envelope'],
  ),

  FAQItem(
    emoji: '👆',
    question: 'What are the swipe actions?',
    answer:
        'Swipe left on any envelope for quick actions: Add Money, Spend, or Transfer. No need to tap through menus!',
    screenshotPath: 'swipe_actions.png',
    tags: ['swipe', 'quick action', 'gesture'],
  ),

  // SCHEDULED PAYMENTS
  FAQItem(
    emoji: '📅',
    question: 'How do I set up recurring payments?',
    answer:
        'Open any envelope and tap "Schedule Payment". Set the amount, frequency, and when it starts. Perfect for bills, subscriptions, or regular savings!',
    screenshotPath: 'scheduled_payment.png',
    tags: ['scheduled', 'recurring', 'payment', 'bill'],
  ),

  FAQItem(
    emoji: '🔔',
    question: 'Will I get notifications for scheduled payments?',
    answer:
        'Yes! The app will show upcoming scheduled payments in the Calendar view. You can see what\'s coming and plan accordingly.',
    screenshotPath: 'calendar_notifications.png',
    tags: ['notification', 'scheduled', 'calendar', 'reminder'],
  ),

  // SECURITY & DATA
  FAQItem(
    emoji: '🔒',
    question: 'Is my data secure?',
    answer:
        'Yes! Your data is stored in Firebase with industry-standard encryption. You can also enable biometric authentication in Settings for extra security.',
    screenshotPath: 'security.png',
    tags: ['security', 'privacy', 'data', 'encryption'],
  ),

  FAQItem(
    emoji: '☁️',
    question: 'Is my data backed up?',
    answer:
        'Absolutely! All your data is automatically synced to the cloud via Firebase. You can access it from any device where you\'re logged in.',
    screenshotPath: 'backup.png',
    tags: ['backup', 'cloud', 'sync', 'data'],
  ),

  // TROUBLESHOOTING
  FAQItem(
    emoji: '❓',
    question: 'Why isn\'t my envelope showing in Pay Day?',
    answer:
        'Make sure auto-fill is enabled in the envelope settings! Only envelopes with auto-fill enabled will appear in Pay Day allocation.',
    screenshotPath: 'auto_fill_settings.png',
    tags: ['pay day', 'auto fill', 'envelope', 'troubleshoot'],
  ),

  FAQItem(
    emoji: '🔄',
    question: 'How do I sync data between devices?',
    answer:
        'Just log in with the same account on each device! Your data will automatically sync across all devices in real-time.',
    screenshotPath: 'sync.png',
    tags: ['sync', 'devices', 'cloud', 'multi-device'],
  ),
];
