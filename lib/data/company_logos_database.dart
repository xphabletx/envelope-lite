// lib/data/company_logos_database.dart
// Comprehensive UK/US company logos database
// Domain only - Clearbit fetches the actual logo

final companyLogosDatabase = {
  // ========================================
  // STREAMING & ENTERTAINMENT
  // ========================================
  'streaming': {
    'Netflix': {'domain': 'netflix.com', 'keywords': ['netflix', 'streaming', 'tv', 'movies', 'video', 'entertainment']},
    'Disney+': {'domain': 'disneyplus.com', 'keywords': ['disney', 'streaming', 'movies', 'entertainment']},
    'Amazon Prime': {'domain': 'amazon.co.uk', 'keywords': ['amazon', 'prime', 'streaming', 'video']},
    'Apple TV+': {'domain': 'apple.com', 'keywords': ['apple', 'tv', 'streaming', 'entertainment']},
    'Spotify': {'domain': 'spotify.com', 'keywords': ['spotify', 'music', 'streaming', 'audio', 'podcast']},
    'YouTube Premium': {'domain': 'youtube.com', 'keywords': ['youtube', 'video', 'streaming', 'google']},
    'Now TV': {'domain': 'nowtv.com', 'keywords': ['now', 'tv', 'streaming', 'sky']},
    'Paramount+': {'domain': 'paramountplus.com', 'keywords': ['paramount', 'streaming', 'movies']},
    'HBO Max': {'domain': 'hbomax.com', 'keywords': ['hbo', 'streaming', 'tv', 'movies']},
    'Hulu': {'domain': 'hulu.com', 'keywords': ['hulu', 'streaming', 'tv']},
    'Peacock': {'domain': 'peacocktv.com', 'keywords': ['peacock', 'streaming', 'nbc']},
    'Apple Music': {'domain': 'apple.com', 'keywords': ['apple', 'music', 'streaming']},
    'Tidal': {'domain': 'tidal.com', 'keywords': ['tidal', 'music', 'streaming']},
    'Deezer': {'domain': 'deezer.com', 'keywords': ['deezer', 'music', 'streaming']},
  },

  // ========================================
  // ENERGY & UTILITIES (UK)
  // ========================================
  'utilities_uk': {
    'British Gas': {'domain': 'britishgas.co.uk', 'keywords': ['british', 'gas', 'energy', 'utility', 'heating']},
    'EDF Energy': {'domain': 'edfenergy.com', 'keywords': ['edf', 'energy', 'electricity', 'utility']},
    'E.ON': {'domain': 'eonenergy.com', 'keywords': ['eon', 'energy', 'electricity', 'utility']},
    'Scottish Power': {'domain': 'scottishpower.co.uk', 'keywords': ['scottish', 'power', 'energy', 'utility']},
    'OVO Energy': {'domain': 'ovoenergy.com', 'keywords': ['ovo', 'energy', 'utility']},
    'Bulb': {'domain': 'bulb.co.uk', 'keywords': ['bulb', 'energy', 'utility']},
    'Octopus Energy': {'domain': 'octopus.energy', 'keywords': ['octopus', 'energy', 'utility']},
    'Shell Energy': {'domain': 'shellenergy.co.uk', 'keywords': ['shell', 'energy', 'utility']},
    'Utilita': {'domain': 'utilita.co.uk', 'keywords': ['utilita', 'energy', 'utility']},
    'npower': {'domain': 'npower.com', 'keywords': ['npower', 'energy', 'utility']},
  },

  // ========================================
  // ENERGY & UTILITIES (US)
  // ========================================
  'utilities_us': {
    'Con Edison': {'domain': 'coned.com', 'keywords': ['con', 'edison', 'energy', 'utility', 'electric']},
    'PG&E': {'domain': 'pge.com', 'keywords': ['pge', 'pacific', 'gas', 'electric', 'utility']},
    'Duke Energy': {'domain': 'duke-energy.com', 'keywords': ['duke', 'energy', 'utility']},
    'Southern Company': {'domain': 'southerncompany.com', 'keywords': ['southern', 'energy', 'utility']},
    'Xcel Energy': {'domain': 'xcelenergy.com', 'keywords': ['xcel', 'energy', 'utility']},
  },

  // ========================================
  // MOBILE & BROADBAND (UK)
  // ========================================
  'mobile_uk': {
    'EE': {'domain': 'ee.co.uk', 'keywords': ['ee', 'mobile', 'phone', 'network', 'broadband']},
    'O2': {'domain': 'o2.co.uk', 'keywords': ['o2', 'mobile', 'phone', 'network']},
    'Vodafone': {'domain': 'vodafone.co.uk', 'keywords': ['vodafone', 'mobile', 'phone', 'network']},
    'Three': {'domain': 'three.co.uk', 'keywords': ['three', 'mobile', 'phone', 'network']},
    'Sky': {'domain': 'sky.com', 'keywords': ['sky', 'tv', 'broadband', 'mobile']},
    'Virgin Media': {'domain': 'virginmedia.com', 'keywords': ['virgin', 'media', 'broadband', 'tv', 'internet']},
    'BT': {'domain': 'bt.com', 'keywords': ['bt', 'broadband', 'phone', 'internet']},
    'TalkTalk': {'domain': 'talktalk.co.uk', 'keywords': ['talktalk', 'broadband', 'internet']},
    'Plusnet': {'domain': 'plusnet.com', 'keywords': ['plusnet', 'broadband', 'internet']},
    'Hyperoptic': {'domain': 'hyperoptic.com', 'keywords': ['hyperoptic', 'broadband', 'internet']},
    'Giffgaff': {'domain': 'giffgaff.com', 'keywords': ['giffgaff', 'mobile', 'phone']},
    'Lebara': {'domain': 'lebara.com', 'keywords': ['lebara', 'mobile', 'phone']},
    'Tesco Mobile': {'domain': 'tescomobile.com', 'keywords': ['tesco', 'mobile', 'phone']},
  },

  // ========================================
  // MOBILE & BROADBAND (US)
  // ========================================
  'mobile_us': {
    'Verizon': {'domain': 'verizon.com', 'keywords': ['verizon', 'mobile', 'phone', 'network']},
    'AT&T': {'domain': 'att.com', 'keywords': ['att', 'mobile', 'phone', 'network']},
    'T-Mobile': {'domain': 't-mobile.com', 'keywords': ['tmobile', 'mobile', 'phone', 'network']},
    'Sprint': {'domain': 'sprint.com', 'keywords': ['sprint', 'mobile', 'phone']},
    'Xfinity': {'domain': 'xfinity.com', 'keywords': ['xfinity', 'internet', 'broadband', 'comcast']},
    'Spectrum': {'domain': 'spectrum.com', 'keywords': ['spectrum', 'internet', 'broadband']},
  },

  // ========================================
  // INSURANCE (UK)
  // ========================================
  'insurance_uk': {
    'Admiral': {'domain': 'admiral.com', 'keywords': ['admiral', 'insurance', 'car', 'home']},
    'Aviva': {'domain': 'aviva.co.uk', 'keywords': ['aviva', 'insurance', 'car', 'home', 'life']},
    'Direct Line': {'domain': 'directline.com', 'keywords': ['direct', 'line', 'insurance', 'car']},
    'Churchill': {'domain': 'churchill.com', 'keywords': ['churchill', 'insurance', 'car']},
    'Hastings Direct': {'domain': 'hastingsdirect.com', 'keywords': ['hastings', 'insurance', 'car']},
    'LV=': {'domain': 'lv.com', 'keywords': ['lv', 'insurance', 'car', 'home']},
    'The AA': {'domain': 'theaa.com', 'keywords': ['aa', 'insurance', 'breakdown', 'car']},
    'RAC': {'domain': 'rac.co.uk', 'keywords': ['rac', 'breakdown', 'insurance', 'car']},
    'Tesco Bank': {'domain': 'tescobank.com', 'keywords': ['tesco', 'bank', 'insurance']},
    'Legal & General': {'domain': 'legalandgeneral.com', 'keywords': ['legal', 'general', 'insurance', 'life']},
  },

  // ========================================
  // INSURANCE (US)
  // ========================================
  'insurance_us': {
    'Geico': {'domain': 'geico.com', 'keywords': ['geico', 'insurance', 'car', 'auto']},
    'State Farm': {'domain': 'statefarm.com', 'keywords': ['state', 'farm', 'insurance']},
    'Allstate': {'domain': 'allstate.com', 'keywords': ['allstate', 'insurance', 'car']},
    'Progressive': {'domain': 'progressive.com', 'keywords': ['progressive', 'insurance', 'car']},
    'Liberty Mutual': {'domain': 'libertymutual.com', 'keywords': ['liberty', 'mutual', 'insurance']},
    'USAA': {'domain': 'usaa.com', 'keywords': ['usaa', 'insurance', 'military']},
  },

  // ========================================
  // SUBSCRIPTIONS & CLOUD
  // ========================================
  'subscriptions': {
    'Google One': {'domain': 'google.com', 'keywords': ['google', 'one', 'storage', 'cloud']},
    'iCloud': {'domain': 'icloud.com', 'keywords': ['icloud', 'apple', 'storage', 'cloud']},
    'Microsoft 365': {'domain': 'microsoft.com', 'keywords': ['microsoft', 'office', '365', 'subscription']},
    'Adobe': {'domain': 'adobe.com', 'keywords': ['adobe', 'creative', 'cloud', 'photoshop']},
    'Dropbox': {'domain': 'dropbox.com', 'keywords': ['dropbox', 'storage', 'cloud']},
    'OneDrive': {'domain': 'onedrive.com', 'keywords': ['onedrive', 'microsoft', 'storage']},
    'ChatGPT Plus': {'domain': 'openai.com', 'keywords': ['chatgpt', 'openai', 'ai', 'subscription']},
    'GitHub': {'domain': 'github.com', 'keywords': ['github', 'code', 'development']},
    'Notion': {'domain': 'notion.so', 'keywords': ['notion', 'productivity', 'notes']},
    'Evernote': {'domain': 'evernote.com', 'keywords': ['evernote', 'notes', 'productivity']},
    'Slack': {'domain': 'slack.com', 'keywords': ['slack', 'communication', 'work']},
    'Zoom': {'domain': 'zoom.us', 'keywords': ['zoom', 'video', 'meetings']},
    'LinkedIn Premium': {'domain': 'linkedin.com', 'keywords': ['linkedin', 'professional', 'network']},
    'Canva Pro': {'domain': 'canva.com', 'keywords': ['canva', 'design', 'graphics']},
  },

  // ========================================
  // FITNESS & GYM
  // ========================================
  'fitness': {
    'PureGym': {'domain': 'puregym.com', 'keywords': ['pure', 'gym', 'fitness', 'exercise']},
    'The Gym Group': {'domain': 'thegymgroup.com', 'keywords': ['gym', 'group', 'fitness']},
    'David Lloyd': {'domain': 'davidlloyd.co.uk', 'keywords': ['david', 'lloyd', 'gym', 'fitness']},
    'Nuffield Health': {'domain': 'nuffieldhealth.com', 'keywords': ['nuffield', 'health', 'gym', 'fitness']},
    'Planet Fitness': {'domain': 'planetfitness.com', 'keywords': ['planet', 'fitness', 'gym']},
    'LA Fitness': {'domain': 'lafitness.com', 'keywords': ['la', 'fitness', 'gym']},
    'Gold\'s Gym': {'domain': 'goldsgym.com', 'keywords': ['golds', 'gym', 'fitness']},
    'Peloton': {'domain': 'onepeloton.com', 'keywords': ['peloton', 'fitness', 'cycling']},
    'ClassPass': {'domain': 'classpass.com', 'keywords': ['classpass', 'fitness', 'class']},
  },

  // ========================================
  // FOOD DELIVERY & RESTAURANTS
  // ========================================
  'food_delivery': {
    'Deliveroo': {'domain': 'deliveroo.co.uk', 'keywords': ['deliveroo', 'food', 'delivery', 'restaurant']},
    'Uber Eats': {'domain': 'ubereats.com', 'keywords': ['uber', 'eats', 'food', 'delivery']},
    'Just Eat': {'domain': 'just-eat.co.uk', 'keywords': ['just', 'eat', 'food', 'delivery']},
    'DoorDash': {'domain': 'doordash.com', 'keywords': ['doordash', 'food', 'delivery']},
    'Grubhub': {'domain': 'grubhub.com', 'keywords': ['grubhub', 'food', 'delivery']},
    'Postmates': {'domain': 'postmates.com', 'keywords': ['postmates', 'delivery', 'food']},
  },

  // ========================================
  // RETAIL (UK)
  // ========================================
  'retail_uk': {
    'Tesco': {'domain': 'tesco.com', 'keywords': ['tesco', 'supermarket', 'grocery', 'shopping']},
    'Sainsbury\'s': {'domain': 'sainsburys.co.uk', 'keywords': ['sainsburys', 'supermarket', 'grocery']},
    'ASDA': {'domain': 'asda.com', 'keywords': ['asda', 'supermarket', 'grocery']},
    'Morrisons': {'domain': 'morrisons.com', 'keywords': ['morrisons', 'supermarket', 'grocery']},
    'Waitrose': {'domain': 'waitrose.com', 'keywords': ['waitrose', 'supermarket', 'grocery']},
    'Marks & Spencer': {'domain': 'marksandspencer.com', 'keywords': ['marks', 'spencer', 'ms', 'retail']},
    'John Lewis': {'domain': 'johnlewis.com', 'keywords': ['john', 'lewis', 'retail', 'department']},
    'Argos': {'domain': 'argos.co.uk', 'keywords': ['argos', 'retail', 'shopping']},
    'Boots': {'domain': 'boots.com', 'keywords': ['boots', 'pharmacy', 'health', 'beauty']},
    'Superdrug': {'domain': 'superdrug.com', 'keywords': ['superdrug', 'pharmacy', 'beauty']},
    'Amazon UK': {'domain': 'amazon.co.uk', 'keywords': ['amazon', 'shopping', 'online', 'retail']},
  },

  // ========================================
  // RETAIL (US)
  // ========================================
  'retail_us': {
    'Walmart': {'domain': 'walmart.com', 'keywords': ['walmart', 'supermarket', 'retail', 'shopping']},
    'Target': {'domain': 'target.com', 'keywords': ['target', 'retail', 'shopping']},
    'Costco': {'domain': 'costco.com', 'keywords': ['costco', 'wholesale', 'shopping']},
    'Whole Foods': {'domain': 'wholefoodsmarket.com', 'keywords': ['whole', 'foods', 'grocery']},
    'CVS': {'domain': 'cvs.com', 'keywords': ['cvs', 'pharmacy', 'health']},
    'Walgreens': {'domain': 'walgreens.com', 'keywords': ['walgreens', 'pharmacy', 'health']},
    'Amazon': {'domain': 'amazon.com', 'keywords': ['amazon', 'shopping', 'online', 'retail']},
  },

  // ========================================
  // BANKS (UK)
  // ========================================
  'banks_uk': {
    'Barclays': {'domain': 'barclays.co.uk', 'keywords': ['barclays', 'bank', 'banking']},
    'HSBC': {'domain': 'hsbc.co.uk', 'keywords': ['hsbc', 'bank', 'banking']},
    'Lloyds': {'domain': 'lloydsbank.com', 'keywords': ['lloyds', 'bank', 'banking']},
    'NatWest': {'domain': 'natwest.com', 'keywords': ['natwest', 'bank', 'banking']},
    'Santander': {'domain': 'santander.co.uk', 'keywords': ['santander', 'bank', 'banking']},
    'Halifax': {'domain': 'halifax.co.uk', 'keywords': ['halifax', 'bank', 'banking']},
    'Nationwide': {'domain': 'nationwide.co.uk', 'keywords': ['nationwide', 'building', 'society', 'bank']},
    'TSB': {'domain': 'tsb.co.uk', 'keywords': ['tsb', 'bank', 'banking']},
    'Monzo': {'domain': 'monzo.com', 'keywords': ['monzo', 'bank', 'digital', 'banking']},
    'Revolut': {'domain': 'revolut.com', 'keywords': ['revolut', 'bank', 'digital', 'banking']},
    'Starling': {'domain': 'starlingbank.com', 'keywords': ['starling', 'bank', 'digital']},
  },

  // ========================================
  // BANKS (US)
  // ========================================
  'banks_us': {
    'Chase': {'domain': 'chase.com', 'keywords': ['chase', 'bank', 'banking']},
    'Bank of America': {'domain': 'bankofamerica.com', 'keywords': ['bank', 'america', 'boa', 'banking']},
    'Wells Fargo': {'domain': 'wellsfargo.com', 'keywords': ['wells', 'fargo', 'bank', 'banking']},
    'Citibank': {'domain': 'citibank.com', 'keywords': ['citi', 'bank', 'banking']},
    'Capital One': {'domain': 'capitalone.com', 'keywords': ['capital', 'one', 'bank', 'credit']},
  },

  // ========================================
  // CREDIT CARDS
  // ========================================
  'credit_cards': {
    'American Express': {'domain': 'americanexpress.com', 'keywords': ['amex', 'american', 'express', 'credit', 'card']},
    'Visa': {'domain': 'visa.com', 'keywords': ['visa', 'credit', 'card']},
    'Mastercard': {'domain': 'mastercard.com', 'keywords': ['mastercard', 'credit', 'card']},
  },

  // ========================================
  // TRANSPORT & AUTO
  // ========================================
  'transport': {
    'Uber': {'domain': 'uber.com', 'keywords': ['uber', 'taxi', 'ride', 'transport']},
    'Lyft': {'domain': 'lyft.com', 'keywords': ['lyft', 'ride', 'transport']},
    'Bolt': {'domain': 'bolt.eu', 'keywords': ['bolt', 'taxi', 'ride']},
    'Shell': {'domain': 'shell.com', 'keywords': ['shell', 'petrol', 'gas', 'fuel']},
    'BP': {'domain': 'bp.com', 'keywords': ['bp', 'petrol', 'gas', 'fuel']},
    'Esso': {'domain': 'esso.co.uk', 'keywords': ['esso', 'petrol', 'gas', 'fuel']},
    'Zipcar': {'domain': 'zipcar.com', 'keywords': ['zipcar', 'car', 'rental', 'sharing']},
  },

  // ========================================
  // GAMING & SOFTWARE
  // ========================================
  'gaming': {
    'PlayStation': {'domain': 'playstation.com', 'keywords': ['playstation', 'ps', 'gaming', 'sony']},
    'Xbox': {'domain': 'xbox.com', 'keywords': ['xbox', 'gaming', 'microsoft']},
    'Nintendo': {'domain': 'nintendo.com', 'keywords': ['nintendo', 'switch', 'gaming']},
    'Steam': {'domain': 'steampowered.com', 'keywords': ['steam', 'gaming', 'pc', 'games']},
    'Epic Games': {'domain': 'epicgames.com', 'keywords': ['epic', 'games', 'gaming', 'fortnite']},
    'EA': {'domain': 'ea.com', 'keywords': ['ea', 'electronic', 'arts', 'gaming']},
    'Ubisoft': {'domain': 'ubisoft.com', 'keywords': ['ubisoft', 'gaming', 'games']},
  },
};