// lib/utils/pay_day_phrases.dart
import 'dart:math';

class PayDayPhrases {
  static const List<String> _bank = [
    'Kerr-ching! 💰',
    'Cha-ching! 🔔',
    'Make it rain! 💸',
    'Payday hype! 🎊',
    'The eagle has landed 🦅',
    'Secure the bag 💼',
    'Get that bread 🍞',
    'Stonks! 📈',
    'Big bank energy ⚡',
    'To the moon! 🚀',
    'Fat stacks incoming 💵',
    'Treat yo self! ✨',
    'Guac is no longer extra 🥑',
    'Dinner is on you! 🍕',
    'Wallet: +100 XP 🎮',
    'Happy wallet, happy life 🌈',
    'Pocketful of sunshine ☀️',
    'Lovely jubbly! 💎',
    'Bit of dosh 💷',
    'Pure moolah 🤑',
    'A spot of lolly 🍭',
    'Wonga in the pocket 🎟️',
    'You earned this! 🌟',
    'Hard work pays off 🛠️',
    'Shine on, big spender! 💎',
    'Level Up! ⬆️',
    'Fresh funds found 🔍',
    'Paid! ✅',
    'Loaded 🔋',
    'Jackpot! 🎰',
  ];

  static String getRandom() => _bank[Random().nextInt(_bank.length)];
}
