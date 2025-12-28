// lib/data/tutorial_sequences.dart

class TutorialStep {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final String? spotlightWidgetKey; // GlobalKey string to find widget

  const TutorialStep({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    this.spotlightWidgetKey,
  });
}

class TutorialSequence {
  final String screenId;
  final String screenName; // Display name for settings
  final List<TutorialStep> steps;

  const TutorialSequence({
    required this.screenId,
    required this.screenName,
    required this.steps,
  });
}

// TUTORIAL DEFINITIONS

const homeTutorial = TutorialSequence(
  screenId: 'home',
  screenName: 'Home Screen',
  steps: [
    TutorialStep(
      id: 'speed_dial',
      emoji: '⚡',
      title: 'Create Your First Envelope',
      description:
          'Tap the + button to create your first envelope! You can also create binders or open the calculator from here! 🎯',
      spotlightWidgetKey: 'fab',
    ),
    TutorialStep(
      id: 'sort_envelopes',
      emoji: '🔍',
      title: 'Sort Your Envelopes',
      description:
          'Tap the sort icon to organize by balance, target, or completion! Find what you need faster! 📊',
      spotlightWidgetKey: 'sort_button',
    ),
    TutorialStep(
      id: 'swipe_actions',
      emoji: '💰',
      title: 'Swipe for Quick Actions',
      description:
          'Swipe left on any envelope to quickly add money, spend, or transfer! No need to tap through menus! 🚀',
      spotlightWidgetKey: null, // No specific spotlight
    ),
    TutorialStep(
      id: 'mine_only',
      emoji: '👥',
      title: 'Mine Only Toggle',
      description:
          'Working with a partner? Toggle "Mine Only" to focus on just your envelopes! 🤝',
      spotlightWidgetKey: 'mine_only_toggle',
    ),
  ],
);

const bindersTutorial = TutorialSequence(
  screenId: 'binders',
  screenName: 'Binders Screen',
  steps: [
    TutorialStep(
      id: 'swipe_binders',
      emoji: '📖',
      title: 'Open Book Design',
      description:
          'Swipe horizontally to browse your binders like a book! Left page shows envelopes, right shows stats! 📚',
      spotlightWidgetKey: null,
    ),
    TutorialStep(
      id: 'binder_history',
      emoji: '📜',
      title: 'Binder Transaction History',
      description:
          'Each binder tracks ALL transactions from every envelope inside it! Tap "View History" to see the full picture! 👀',
      spotlightWidgetKey: 'view_history_button',
    ),
    TutorialStep(
      id: 'quick_envelope',
      emoji: '⚡',
      title: 'Quick Envelope Access',
      description:
          'Tap any envelope in your binder to jump straight into it! No need to go back home! 🏃‍♂️',
      spotlightWidgetKey: null,
    ),
  ],
);

const envelopeDetailTutorial = TutorialSequence(
  screenId: 'envelope_detail',
  screenName: 'Envelope Details',
  steps: [
    TutorialStep(
      id: 'calculator_chip',
      emoji: '🧮',
      title: 'Built-in Calculator',
      description:
          'See that calculator chip? Tap it when entering amounts! No need to open another app! 💡',
      spotlightWidgetKey: 'calculator_chip',
    ),
    TutorialStep(
      id: 'month_navigation',
      emoji: '📅',
      title: 'Month Navigation',
      description:
          'Filter transactions by month! Swipe or use the < > arrows to browse your spending history! 📊',
      spotlightWidgetKey: 'month_selector',
    ),
    TutorialStep(
      id: 'target_suggestions',
      emoji: '🎯',
      title: 'Target Suggestions',
      description:
          'Your target card shows smart suggestions! It calculates how much to save daily/weekly/monthly! 🤓',
      spotlightWidgetKey: 'target_card',
    ),
    TutorialStep(
      id: 'envelope_speed_dial',
      emoji: '⚡',
      title: 'Speed Dial Actions',
      description:
          'Tap the + button for quick actions: Deposit, Withdraw, Transfer, or Calculator! 🚀',
      spotlightWidgetKey: 'envelope_fab',
    ),
    TutorialStep(
      id: 'jump_to_binder',
      emoji: '🔗',
      title: 'Jump to Binder',
      description:
          'Your envelope is in a binder? Tap the binder name to jump to it! ⚡',
      spotlightWidgetKey: 'binder_link',
    ),
  ],
);

const calendarTutorial = TutorialSequence(
  screenId: 'calendar',
  screenName: 'Calendar',
  steps: [
    TutorialStep(
      id: 'week_view',
      emoji: '📆',
      title: 'Week View Toggle',
      description:
          'Switch between month and week view! Week view is perfect for planning your next few days! 📱',
      spotlightWidgetKey: 'view_toggle',
    ),
    TutorialStep(
      id: 'future_projection',
      emoji: '🔮',
      title: 'Future Projections',
      description:
          'Tap any future date to see a projection of your finances on that day! Time travel for your budget! ⏰',
      spotlightWidgetKey: null,
    ),
  ],
);

const accountsTutorial = TutorialSequence(
  screenId: 'accounts',
  screenName: 'Accounts',
  steps: [
    TutorialStep(
      id: 'credit_cards',
      emoji: '💳',
      title: 'Credit Card Tracking',
      description:
          'Credit cards show as negative balances! Track your debt and available credit in one place! 📊',
      spotlightWidgetKey: null,
    ),
    TutorialStep(
      id: 'balance_breakdown',
      emoji: '📊',
      title: 'Assigned vs Available',
      description:
          'Your account shows Assigned (money in envelopes) vs Available (unallocated funds)! Know what\'s really free! 💰',
      spotlightWidgetKey: 'balance_card',
    ),
  ],
);

const settingsTutorial = TutorialSequence(
  screenId: 'settings',
  screenName: 'Settings',
  steps: [
    TutorialStep(
      id: 'themes',
      emoji: '🎨',
      title: 'Theme Gallery',
      description:
          'We have 6 gorgeous themes! Each with 4 binder color variants = 24 combinations! Find your vibe! ✨',
      spotlightWidgetKey: 'theme_selector',
    ),
    TutorialStep(
      id: 'fonts',
      emoji: '✍️',
      title: 'Handwriting Fonts',
      description:
          'Try our handwriting fonts like Caveat and Indie Flower! Makes your budget feel personal! 🖊️',
      spotlightWidgetKey: 'font_picker',
    ),
    TutorialStep(
      id: 'business_icons',
      emoji: '🏢',
      title: 'Business Icons',
      description:
          '150+ company logos available! Find your favorite brands in the icon picker! 🎯',
      spotlightWidgetKey: null,
    ),
    TutorialStep(
      id: 'export_excel',
      emoji: '📤',
      title: 'Export to Excel',
      description:
          'Export all your data to Excel with 6 detailed sheets! Perfect for end-of-year reviews! 📊',
      spotlightWidgetKey: 'export_option',
    ),
  ],
);

const payDayTutorial = TutorialSequence(
  screenId: 'pay_day',
  screenName: 'Pay Day',
  steps: [
    TutorialStep(
      id: 'auto_fill',
      emoji: '🤖',
      title: 'Auto-Fill Magic',
      description:
          'Enable auto-fill on envelopes and they\'ll fill themselves on Pay Day! Set it and forget it! ✨',
      spotlightWidgetKey: 'auto_fill_toggle',
    ),
    TutorialStep(
      id: 'allocation',
      emoji: '📊',
      title: 'Smart Allocation',
      description:
          'Pay Day shows what\'s already allocated vs what\'s left! No math needed! 🧮',
      spotlightWidgetKey: 'allocation_summary',
    ),
    TutorialStep(
      id: 'toggle_envelopes',
      emoji: '✅',
      title: 'Toggle Before Execute',
      description:
          'Uncheck envelopes you don\'t want to fill this time! Full control every Pay Day! 🎯',
      spotlightWidgetKey: null,
    ),
  ],
);

const timeMachineTutorial = TutorialSequence(
  screenId: 'time_machine',
  screenName: 'Time Machine',
  steps: [
    TutorialStep(
      id: 'time_travel',
      emoji: '⏰',
      title: 'Financial Time Travel',
      description:
          'See exactly where you\'ll be financially on any future date! Plan ahead with confidence! 🚀',
      spotlightWidgetKey: 'date_picker',
    ),
    TutorialStep(
      id: 'pay_settings',
      emoji: '💰',
      title: 'Adjust Pay Settings',
      description:
          'Change your pay amount or frequency to see different scenarios! What if you got a raise? 📈',
      spotlightWidgetKey: 'pay_settings',
    ),
    TutorialStep(
      id: 'toggle_expenses',
      emoji: '🎯',
      title: 'Toggle Expenses',
      description:
          'Turn off scheduled payments or envelopes to see "what if" scenarios! Test before committing! 🤔',
      spotlightWidgetKey: 'toggle_switches',
    ),
    TutorialStep(
      id: 'enter_projection',
      emoji: '✨',
      title: 'Enter Projection',
      description:
          'Tap "Enter Time Machine" to view your ENTIRE app as if it were that future date! Mind = Blown! 🤯',
      spotlightWidgetKey: 'enter_button',
    ),
  ],
);

const workspaceTutorial = TutorialSequence(
  screenId: 'workspace',
  screenName: 'Workspace',
  steps: [
    TutorialStep(
      id: 'partner_budgeting',
      emoji: '💑',
      title: 'Partner Budgeting',
      description:
          'Join a workspace to budget together! See each other\'s envelopes in real-time! 👫',
      spotlightWidgetKey: 'join_workspace',
    ),
    TutorialStep(
      id: 'transfer_partners',
      emoji: '💸',
      title: 'Transfer Between Partners',
      description:
          'Send money between your envelopes and your partner\'s! Perfect for shared expenses! 🤝',
      spotlightWidgetKey: null,
    ),
    TutorialStep(
      id: 'partner_badges',
      emoji: '👤',
      title: 'Partner Badges',
      description:
          'Look for badges showing who owns each envelope! Know what\'s yours, what\'s theirs, what\'s shared! 🏷️',
      spotlightWidgetKey: null,
    ),
  ],
);

// MASTER LIST
const allTutorials = [
  homeTutorial,
  bindersTutorial,
  envelopeDetailTutorial,
  calendarTutorial,
  accountsTutorial,
  settingsTutorial,
  payDayTutorial,
  timeMachineTutorial,
  workspaceTutorial,
];
