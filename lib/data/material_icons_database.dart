// lib/data/material_icons_database.dart
import 'package:flutter/material.dart';

final materialIconsDatabase = {
  // Finance
  'account_balance_wallet': {
    'icon': Icons.account_balance_wallet,
    'keywords': ['wallet', 'money', 'payment', 'finance', 'cash', 'card', 'purse'],
    'category': 'finance',
  },
  'account_balance': {
    'icon': Icons.account_balance,
    'keywords': ['bank', 'banking', 'finance', 'money', 'institution', 'building'],
    'category': 'finance',
  },
  'attach_money': {
    'icon': Icons.attach_money,
    'keywords': ['money', 'dollar', 'cash', 'currency', 'finance', 'payment'],
    'category': 'finance',
  },
  'credit_card': {
    'icon': Icons.credit_card,
    'keywords': ['card', 'credit', 'payment', 'debit', 'finance', 'bank'],
    'category': 'finance',
  },
  'payment': {
    'icon': Icons.payment,
    'keywords': ['payment', 'card', 'credit', 'pay', 'transaction'],
    'category': 'finance',
  },
  'payments': {
    'icon': Icons.payments,
    'keywords': ['payments', 'money', 'transactions', 'finance'],
    'category': 'finance',
  },
  'savings': {
    'icon': Icons.savings,
    'keywords': ['savings', 'piggy', 'bank', 'save', 'money'],
    'category': 'finance',
  },
  'currency_pound': {
    'icon': Icons.currency_pound,
    'keywords': ['pound', 'gbp', 'sterling', 'money', 'british', 'uk'],
    'category': 'finance',
  },
  'euro': {
    'icon': Icons.euro,
    'keywords': ['euro', 'eur', 'money', 'currency', 'europe'],
    'category': 'finance',
  },

  // Home & Living
  'home': {
    'icon': Icons.home,
    'keywords': ['home', 'house', 'property', 'rent', 'mortgage', 'living', 'residence'],
    'category': 'home',
  },
  'house': {
    'icon': Icons.house,
    'keywords': ['house', 'home', 'property', 'building', 'residence'],
    'category': 'home',
  },
  'apartment': {
    'icon': Icons.apartment,
    'keywords': ['apartment', 'flat', 'condo', 'building', 'housing'],
    'category': 'home',
  },
  'bed': {
    'icon': Icons.bed,
    'keywords': ['bed', 'sleep', 'bedroom', 'rest', 'hotel'],
    'category': 'home',
  },
  'chair': {
    'icon': Icons.chair,
    'keywords': ['chair', 'furniture', 'seat', 'sitting'],
    'category': 'home',
  },
  'weekend': {
    'icon': Icons.weekend,
    'keywords': ['sofa', 'couch', 'furniture', 'relax', 'living room'],
    'category': 'home',
  },

  // Food & Dining
  'restaurant': {
    'icon': Icons.restaurant,
    'keywords': ['restaurant', 'food', 'dining', 'eat', 'meal', 'dinner'],
    'category': 'food',
  },
  'fastfood': {
    'icon': Icons.fastfood,
    'keywords': ['fastfood', 'burger', 'food', 'quick', 'takeaway', 'junk'],
    'category': 'food',
  },
  'local_dining': {
    'icon': Icons.local_dining,
    'keywords': ['dining', 'food', 'fork', 'knife', 'eat', 'meal'],
    'category': 'food',
  },
  'local_pizza': {
    'icon': Icons.local_pizza,
    'keywords': ['pizza', 'food', 'italian', 'delivery', 'takeaway'],
    'category': 'food',
  },
  'local_cafe': {
    'icon': Icons.local_cafe,
    'keywords': ['cafe', 'coffee', 'tea', 'drink', 'breakfast'],
    'category': 'food',
  },
  'local_bar': {
    'icon': Icons.local_bar,
    'keywords': ['bar', 'drink', 'cocktail', 'alcohol', 'pub'],
    'category': 'food',
  },
  'cake': {
    'icon': Icons.cake,
    'keywords': ['cake', 'dessert', 'sweet', 'birthday', 'bakery', 'celebration', 'party'],
    'category': 'food',
  },
  'icecream': {
    'icon': Icons.icecream,
    'keywords': ['icecream', 'dessert', 'sweet', 'cold', 'treat'],
    'category': 'food',
  },

  // Transportation & Fuel
  'local_gas_station': {
    'icon': Icons.local_gas_station,
    'keywords': ['fuel', 'gas', 'petrol', 'gasoline', 'station', 'pump', 'car'],
    'category': 'transportation',
  },
  'directions_car': {
    'icon': Icons.directions_car,
    'keywords': ['car', 'vehicle', 'auto', 'automobile', 'transport', 'fuel', 'gas'],
    'category': 'transportation',
  },
  'ev_station': {
    'icon': Icons.ev_station,
    'keywords': ['electric', 'vehicle', 'car', 'ev', 'charging', 'station', 'fuel'],
    'category': 'transportation',
  },
  'directions_bus': {
    'icon': Icons.directions_bus,
    'keywords': ['bus', 'transport', 'public', 'transit'],
    'category': 'transportation',
  },
  'directions_subway': {
    'icon': Icons.directions_subway,
    'keywords': ['subway', 'metro', 'train', 'transport', 'transit'],
    'category': 'transportation',
  },
  'train': {
    'icon': Icons.train,
    'keywords': ['train', 'transport', 'transit', 'railway'],
    'category': 'transportation',
  },
  'flight': {
    'icon': Icons.flight,
    'keywords': ['flight', 'airplane', 'plane', 'travel', 'transport'],
    'category': 'transportation',
  },
  'local_shipping': {
    'icon': Icons.local_shipping,
    'keywords': ['shipping', 'delivery', 'truck', 'transport'],
    'category': 'transportation',
  },

  // Utilities & Bills
  'bolt': {
    'icon': Icons.bolt,
    'keywords': ['electricity', 'power', 'energy', 'electric', 'utility', 'lightning'],
    'category': 'utilities',
  },
  'lightbulb': {
    'icon': Icons.lightbulb,
    'keywords': ['light', 'bulb', 'electricity', 'idea', 'power'],
    'category': 'utilities',
  },
  'water_drop': {
    'icon': Icons.water_drop,
    'keywords': ['water', 'drop', 'utility', 'liquid', 'h2o'],
    'category': 'utilities',
  },
  'local_fire_department': {
    'icon': Icons.local_fire_department,
    'keywords': ['fire', 'emergency', 'heat', 'heating', 'gas'],
    'category': 'utilities',
  },
  'thermostat': {
    'icon': Icons.thermostat,
    'keywords': ['thermostat', 'heating', 'temperature', 'climate', 'hvac'],
    'category': 'utilities',
  },
  'wifi': {
    'icon': Icons.wifi,
    'keywords': ['wifi', 'internet', 'broadband', 'network', 'connection'],
    'category': 'utilities',
  },

  // Communication
  'phone': {
    'icon': Icons.phone,
    'keywords': ['phone', 'mobile', 'cell', 'telephone', 'contact', 'call'],
    'category': 'communication',
  },
  'smartphone': {
    'icon': Icons.smartphone,
    'keywords': ['phone', 'mobile', 'cell', 'smartphone', 'device'],
    'category': 'communication',
  },

  // Entertainment
  'tv': {
    'icon': Icons.tv,
    'keywords': ['tv', 'television', 'streaming', 'video', 'entertainment', 'netflix'],
    'category': 'entertainment',
  },
  'movie': {
    'icon': Icons.movie,
    'keywords': ['movie', 'film', 'cinema', 'entertainment', 'video', 'netflix'],
    'category': 'entertainment',
  },
  'music_note': {
    'icon': Icons.music_note,
    'keywords': ['music', 'audio', 'sound', 'spotify', 'song'],
    'category': 'entertainment',
  },
  'videogame_asset': {
    'icon': Icons.videogame_asset,
    'keywords': ['game', 'gaming', 'play', 'entertainment', 'video'],
    'category': 'entertainment',
  },

  // Shopping
  'shopping_cart': {
    'icon': Icons.shopping_cart,
    'keywords': ['shopping', 'cart', 'groceries', 'store', 'buy', 'purchase'],
    'category': 'shopping',
  },
  'shopping_bag': {
    'icon': Icons.shopping_bag,
    'keywords': ['shopping', 'bag', 'retail', 'purchase', 'clothes'],
    'category': 'shopping',
  },
  'store': {
    'icon': Icons.store,
    'keywords': ['store', 'shop', 'retail', 'mall', 'market'],
    'category': 'shopping',
  },
  'local_mall': {
    'icon': Icons.local_mall,
    'keywords': ['mall', 'shopping', 'center', 'retail', 'store'],
    'category': 'shopping',
  },
  'local_grocery_store': {
    'icon': Icons.local_grocery_store,
    'keywords': ['grocery', 'store', 'food', 'shopping', 'supermarket'],
    'category': 'shopping',
  },
  'local_offer': {
    'icon': Icons.local_offer,
    'keywords': ['offer', 'sale', 'discount', 'deal', 'tag', 'price'],
    'category': 'shopping',
  },

  // Health & Fitness
  'fitness_center': {
    'icon': Icons.fitness_center,
    'keywords': ['gym', 'fitness', 'exercise', 'workout', 'health'],
    'category': 'health',
  },
  'local_hospital': {
    'icon': Icons.local_hospital,
    'keywords': ['hospital', 'medical', 'health', 'doctor', 'clinic'],
    'category': 'health',
  },
  'medical_services': {
    'icon': Icons.medical_services,
    'keywords': ['medical', 'health', 'doctor', 'healthcare', 'clinic'],
    'category': 'health',
  },
  'medication': {
    'icon': Icons.medication,
    'keywords': ['medication', 'medicine', 'pills', 'pharmacy', 'health'],
    'category': 'health',
  },
  'local_pharmacy': {
    'icon': Icons.local_pharmacy,
    'keywords': ['pharmacy', 'chemist', 'medicine', 'drugstore', 'health'],
    'category': 'health',
  },
  'spa': {
    'icon': Icons.spa,
    'keywords': ['spa', 'massage', 'relax', 'wellness', 'beauty'],
    'category': 'health',
  },

  // Personal Care & Beauty
  'content_cut': {
    'icon': Icons.content_cut,
    'keywords': ['cut', 'scissors', 'haircut', 'hairdresser', 'barber', 'salon', 'trim', 'stylist', 'hair'],
    'category': 'beauty',
  },

  // Clothing & Fashion
  'checkroom': {
    'icon': Icons.checkroom,
    'keywords': ['clothes', 'wardrobe', 'clothing', 'fashion', 'dress', 'outfit', 'garment'],
    'category': 'shopping',
  },

  // Celebrations & Events
  'celebration': {
    'icon': Icons.celebration,
    'keywords': ['celebration', 'party', 'christmas', 'birthday', 'event', 'festive', 'holiday', 'xmas'],
    'category': 'other',
  },
  'card_giftcard': {
    'icon': Icons.card_giftcard,
    'keywords': ['gift', 'present', 'christmas', 'birthday', 'card', 'voucher', 'xmas'],
    'category': 'other',
  },

  // Tickets & Events
  'confirmation_number': {
    'icon': Icons.confirmation_number,
    'keywords': ['ticket', 'tickets', 'event', 'concert', 'cinema', 'show', 'admission', 'booking'],
    'category': 'entertainment',
  },
  'local_activity': {
    'icon': Icons.local_activity,
    'keywords': ['ticket', 'tickets', 'event', 'activity', 'entertainment', 'show'],
    'category': 'entertainment',
  },

  // Other
  'pets': {
    'icon': Icons.pets,
    'keywords': ['pets', 'animal', 'dog', 'cat', 'vet'],
    'category': 'other',
  },
  'school': {
    'icon': Icons.school,
    'keywords': ['school', 'education', 'learning', 'student'],
    'category': 'other',
  },
  'work': {
    'icon': Icons.work,
    'keywords': ['work', 'job', 'office', 'business', 'career'],
    'category': 'other',
  },
  'hotel': {
    'icon': Icons.hotel,
    'keywords': ['hotel', 'accommodation', 'stay', 'bed', 'lodging', 'motel'],
    'category': 'other',
  },
  'beach_access': {
    'icon': Icons.beach_access,
    'keywords': ['beach', 'vacation', 'holiday', 'sand', 'sun', 'seaside'],
    'category': 'other',
  },
  'luggage': {
    'icon': Icons.luggage,
    'keywords': ['luggage', 'suitcase', 'travel', 'holiday', 'vacation', 'trip', 'bags'],
    'category': 'other',
  },
};
