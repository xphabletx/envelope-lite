// lib/data/binder_templates.dart

class EnvelopeTemplate {
  final String name;
  final String emoji;

  const EnvelopeTemplate({
    required this.name,
    required this.emoji,
  });
}

class BinderTemplate {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> envelopeNames;
  final List<EnvelopeTemplate> envelopes;

  const BinderTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    @Deprecated('Use envelopes instead')
    this.envelopeNames = const [],
    required this.envelopes,
  });
}

const List<BinderTemplate> binderTemplates = [
  BinderTemplate(
    id: 'household',
    name: 'Household',
    emoji: '🏠',
    description: 'Essential home expenses',
    envelopes: [
      EnvelopeTemplate(name: 'Rent/Mortgage', emoji: '🏡'),
      EnvelopeTemplate(name: 'Council/Property Tax', emoji: '🏛️'),
      EnvelopeTemplate(name: 'Gas', emoji: '🔥'),
      EnvelopeTemplate(name: 'Electric', emoji: '⚡'),
      EnvelopeTemplate(name: 'Water', emoji: '💧'),
      EnvelopeTemplate(name: 'Broadband', emoji: '🌐'),
      EnvelopeTemplate(name: 'Insurance', emoji: '🛡️'),
      EnvelopeTemplate(name: 'Emergency Repairs', emoji: '🔧'),
    ],
  ),
  BinderTemplate(
    id: 'car',
    name: 'Car',
    emoji: '🚗',
    description: 'Vehicle running costs',
    envelopes: [
      EnvelopeTemplate(name: 'Finance', emoji: '💳'),
      EnvelopeTemplate(name: 'MOT/Inspection', emoji: '🔍'),
      EnvelopeTemplate(name: 'Tax', emoji: '📋'),
      EnvelopeTemplate(name: 'Fuel', emoji: '⛽'),
      EnvelopeTemplate(name: 'Service', emoji: '🔧'),
      EnvelopeTemplate(name: 'Tyres', emoji: '🛞'),
      EnvelopeTemplate(name: 'Insurance', emoji: '🛡️'),
      EnvelopeTemplate(name: 'Emergency Repairs', emoji: '🚨'),
    ],
  ),
  BinderTemplate(
    id: 'kids',
    name: 'Kids',
    emoji: '👶',
    description: 'Children\'s expenses',
    envelopes: [
      EnvelopeTemplate(name: 'Uniform', emoji: '👔'),
      EnvelopeTemplate(name: 'After School Clubs', emoji: '⚽'),
      EnvelopeTemplate(name: 'Fees', emoji: '🎓'),
      EnvelopeTemplate(name: 'Books', emoji: '📚'),
      EnvelopeTemplate(name: 'Trips', emoji: '🚌'),
      EnvelopeTemplate(name: 'Parties', emoji: '🎉'),
    ],
  ),
  BinderTemplate(
    id: 'shopping',
    name: 'Shopping',
    emoji: '🛒',
    description: 'Household purchases',
    envelopes: [
      EnvelopeTemplate(name: 'Groceries', emoji: '🥬'),
      EnvelopeTemplate(name: 'Clothes', emoji: '👕'),
      EnvelopeTemplate(name: 'Shoes', emoji: '👟'),
      EnvelopeTemplate(name: 'Furniture', emoji: '🛋️'),
      EnvelopeTemplate(name: 'Electronics', emoji: '📱'),
      EnvelopeTemplate(name: 'Garden', emoji: '🌱'),
    ],
  ),
];
