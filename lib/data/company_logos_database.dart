// lib/data/company_logos_database.dart
// MASSIVE UK/US company logos database
// Domain only - Used for fetching high-res logos/favicons

final companyLogosDatabase = {
  // ========================================
  // SOCIAL MEDIA & COMMUNICATION (NEW!)
  // ========================================
  'social': {
    'Facebook': {
      'domain': 'facebook.com',
      'keywords': ['facebook', 'social', 'meta', 'network', 'friends'],
    },
    'Instagram': {
      'domain': 'instagram.com',
      'keywords': ['instagram', 'social', 'photo', 'meta', 'camera', 'stories'],
    },
    'Twitter': {
      'domain': 'twitter.com',
      'keywords': ['twitter', 'x', 'tweet', 'social', 'bird', 'news'],
    },
    'TikTok': {
      'domain': 'tiktok.com',
      'keywords': ['tiktok', 'video', 'social', 'dance', 'viral'],
    },
    'Snapchat': {
      'domain': 'snapchat.com',
      'keywords': ['snapchat', 'snap', 'social', 'photo', 'ghost'],
    },
    'LinkedIn': {
      'domain': 'linkedin.com',
      'keywords': ['linkedin', 'work', 'job', 'social', 'network', 'career'],
    },
    'Pinterest': {
      'domain': 'pinterest.com',
      'keywords': ['pinterest', 'pin', 'creative', 'social', 'ideas'],
    },
    'Reddit': {
      'domain': 'reddit.com',
      'keywords': ['reddit', 'forum', 'news', 'social', 'community'],
    },
    'WhatsApp': {
      'domain': 'whatsapp.com',
      'keywords': ['whatsapp', 'chat', 'message', 'call', 'social'],
    },
    'Telegram': {
      'domain': 'telegram.org',
      'keywords': ['telegram', 'chat', 'message', 'secure'],
    },
    'Discord': {
      'domain': 'discord.com',
      'keywords': ['discord', 'chat', 'gaming', 'voice', 'server'],
    },
    'Twitch': {
      'domain': 'twitch.tv',
      'keywords': ['twitch', 'streaming', 'gaming', 'live'],
    },
    'YouTube': {
      'domain': 'youtube.com',
      'keywords': ['youtube', 'video', 'google', 'streaming', 'media'],
    },
    'Vimeo': {
      'domain': 'vimeo.com',
      'keywords': ['vimeo', 'video', 'creative', 'streaming'],
    },
  },

  // ========================================
  // FINTECH & PAYMENTS (NEW!)
  // ========================================
  'fintech': {
    'PayPal': {
      'domain': 'paypal.com',
      'keywords': ['paypal', 'payment', 'money', 'wallet', 'online'],
    },
    'Stripe': {
      'domain': 'stripe.com',
      'keywords': ['stripe', 'payment', 'business', 'api'],
    },
    'Square': {
      'domain': 'squareup.com',
      'keywords': ['square', 'payment', 'business', 'pos'],
    },
    'Venmo': {
      'domain': 'venmo.com',
      'keywords': ['venmo', 'payment', 'money', 'split', 'cash'],
    },
    'Cash App': {
      'domain': 'cash.app',
      'keywords': ['cash', 'app', 'payment', 'money', 'bitcoin'],
    },
    'Wise': {
      'domain': 'wise.com',
      'keywords': ['wise', 'transfer', 'money', 'currency', 'travel'],
    },
    'Klarna': {
      'domain': 'klarna.com',
      'keywords': ['klarna', 'payment', 'shopping', 'bnpl'],
    },
    'Affirm': {
      'domain': 'affirm.com',
      'keywords': ['affirm', 'payment', 'shopping', 'credit'],
    },
    'Western Union': {
      'domain': 'westernunion.com',
      'keywords': ['western', 'union', 'money', 'transfer'],
    },
    'Curve': {
      'domain': 'curve.com',
      'keywords': ['curve', 'card', 'finance', 'wallet'],
    },
  },

  // ========================================
  // STREAMING & ENTERTAINMENT
  // ========================================
  'streaming': {
    'Netflix': {
      'domain': 'netflix.com',
      'keywords': [
        'netflix',
        'streaming',
        'tv',
        'movies',
        'video',
        'entertainment',
        'chill',
      ],
    },
    'Disney+': {
      'domain': 'disneyplus.com',
      'keywords': [
        'disney',
        'streaming',
        'movies',
        'entertainment',
        'pixar',
        'marvel',
      ],
    },
    'Amazon Prime': {
      'domain': 'amazon.co.uk',
      'keywords': ['amazon', 'prime', 'streaming', 'video', 'delivery'],
    },
    'Apple TV+': {
      'domain': 'apple.com',
      'keywords': ['apple', 'tv', 'streaming', 'entertainment'],
    },
    'Spotify': {
      'domain': 'spotify.com',
      'keywords': [
        'spotify',
        'music',
        'streaming',
        'audio',
        'podcast',
        'songs',
      ],
    },
    'SoundCloud': {
      'domain': 'soundcloud.com',
      'keywords': ['soundcloud', 'music', 'audio', 'streaming'],
    },
    'Audible': {
      'domain': 'audible.com',
      'keywords': ['audible', 'books', 'audio', 'amazon', 'listening'],
    },
    'YouTube Premium': {
      'domain': 'youtube.com',
      'keywords': ['youtube', 'video', 'streaming', 'google', 'red'],
    },
    'Now TV': {
      'domain': 'nowtv.com',
      'keywords': ['now', 'tv', 'streaming', 'sky', 'movies'],
    },
    'Paramount+': {
      'domain': 'paramountplus.com',
      'keywords': ['paramount', 'streaming', 'movies', 'showtime'],
    },
    'HBO Max': {
      'domain': 'hbomax.com',
      'keywords': ['hbo', 'max', 'streaming', 'tv', 'movies', 'warner'],
    },
    'Hulu': {
      'domain': 'hulu.com',
      'keywords': ['hulu', 'streaming', 'tv', 'shows'],
    },
    'Peacock': {
      'domain': 'peacocktv.com',
      'keywords': ['peacock', 'streaming', 'nbc', 'universal'],
    },
    'Apple Music': {
      'domain': 'music.apple.com',
      'keywords': ['apple', 'music', 'streaming', 'itunes'],
    },
    'Tidal': {
      'domain': 'tidal.com',
      'keywords': ['tidal', 'music', 'streaming', 'hifi'],
    },
    'Deezer': {
      'domain': 'deezer.com',
      'keywords': ['deezer', 'music', 'streaming'],
    },
  },

  // ========================================
  // PRODUCTIVITY & WORK TOOLS (NEW!)
  // ========================================
  'productivity': {
    'Slack': {
      'domain': 'slack.com',
      'keywords': ['slack', 'chat', 'work', 'team', 'business'],
    },
    'Zoom': {
      'domain': 'zoom.us',
      'keywords': ['zoom', 'video', 'meeting', 'call', 'conference'],
    },
    'Microsoft Teams': {
      'domain': 'microsoft.com',
      'keywords': ['teams', 'microsoft', 'chat', 'meeting', 'work'],
    },
    'Trello': {
      'domain': 'trello.com',
      'keywords': ['trello', 'kanban', 'project', 'work', 'atlassian'],
    },
    'Asana': {
      'domain': 'asana.com',
      'keywords': ['asana', 'project', 'management', 'work', 'task'],
    },
    'Jira': {
      'domain': 'atlassian.com',
      'keywords': ['jira', 'software', 'dev', 'issue', 'tracking'],
    },
    'Notion': {
      'domain': 'notion.so',
      'keywords': ['notion', 'notes', 'wiki', 'docs', 'productivity'],
    },
    'Evernote': {
      'domain': 'evernote.com',
      'keywords': ['evernote', 'notes', 'writing', 'notebook'],
    },
    'Canva': {
      'domain': 'canva.com',
      'keywords': ['canva', 'design', 'graphic', 'art', 'social'],
    },
    'Figma': {
      'domain': 'figma.com',
      'keywords': ['figma', 'design', 'ui', 'ux', 'web'],
    },
    'Dropbox': {
      'domain': 'dropbox.com',
      'keywords': ['dropbox', 'file', 'storage', 'cloud', 'share'],
    },
    'Google Drive': {
      'domain': 'drive.google.com',
      'keywords': ['drive', 'google', 'cloud', 'storage', 'file'],
    },
    'WeTransfer': {
      'domain': 'wetransfer.com',
      'keywords': ['wetransfer', 'file', 'share', 'transfer'],
    },
  },

  // ========================================
  // TECH & HARDWARE (NEW!)
  // ========================================
  'tech': {
    'Apple': {
      'domain': 'apple.com',
      'keywords': ['apple', 'iphone', 'mac', 'ipad', 'tech'],
    },
    'Google': {
      'domain': 'google.com',
      'keywords': ['google', 'search', 'tech', 'android', 'pixel'],
    },
    'Samsung': {
      'domain': 'samsung.com',
      'keywords': ['samsung', 'galaxy', 'android', 'tv', 'tech'],
    },
    'Microsoft': {
      'domain': 'microsoft.com',
      'keywords': ['microsoft', 'windows', 'surface', 'tech', 'software'],
    },
    'Sony': {
      'domain': 'sony.com',
      'keywords': ['sony', 'tech', 'tv', 'audio', 'camera'],
    },
    'Dell': {
      'domain': 'dell.com',
      'keywords': ['dell', 'computer', 'laptop', 'pc', 'tech'],
    },
    'HP': {
      'domain': 'hp.com',
      'keywords': ['hp', 'computer', 'laptop', 'printer', 'tech'],
    },
    'Lenovo': {
      'domain': 'lenovo.com',
      'keywords': ['lenovo', 'computer', 'laptop', 'thinkpad'],
    },
    'Intel': {
      'domain': 'intel.com',
      'keywords': ['intel', 'chip', 'processor', 'tech'],
    },
    'Nvidia': {
      'domain': 'nvidia.com',
      'keywords': ['nvidia', 'gpu', 'graphics', 'gaming', 'ai'],
    },
  },

  // ========================================
  // TRAVEL & AIRLINES (NEW!)
  // ========================================
  'travel': {
    'Airbnb': {
      'domain': 'airbnb.com',
      'keywords': ['airbnb', 'stay', 'rent', 'holiday', 'travel'],
    },
    'Booking.com': {
      'domain': 'booking.com',
      'keywords': ['booking', 'hotel', 'travel', 'holiday'],
    },
    'Expedia': {
      'domain': 'expedia.com',
      'keywords': ['expedia', 'travel', 'flight', 'hotel'],
    },
    'Skyscanner': {
      'domain': 'skyscanner.net',
      'keywords': ['skyscanner', 'flight', 'travel', 'cheap'],
    },
    'Tripadvisor': {
      'domain': 'tripadvisor.com',
      'keywords': ['tripadvisor', 'review', 'travel', 'hotel'],
    },
    'British Airways': {
      'domain': 'britishairways.com',
      'keywords': ['ba', 'british', 'airways', 'flight', 'travel', 'plane'],
    },
    'Virgin Atlantic': {
      'domain': 'virginatlantic.com',
      'keywords': ['virgin', 'atlantic', 'flight', 'travel', 'plane'],
    },
    'EasyJet': {
      'domain': 'easyjet.com',
      'keywords': ['easyjet', 'flight', 'travel', 'budget', 'plane'],
    },
    'Ryanair': {
      'domain': 'ryanair.com',
      'keywords': ['ryanair', 'flight', 'travel', 'budget', 'plane'],
    },
    'American Airlines': {
      'domain': 'aa.com',
      'keywords': ['american', 'airlines', 'aa', 'flight', 'travel'],
    },
    'Delta': {
      'domain': 'delta.com',
      'keywords': ['delta', 'airlines', 'flight', 'travel'],
    },
    'United': {
      'domain': 'united.com',
      'keywords': ['united', 'airlines', 'flight', 'travel'],
    },
    'Emirates': {
      'domain': 'emirates.com',
      'keywords': ['emirates', 'flight', 'travel', 'dubai'],
    },
  },

  // ========================================
  // FAST FOOD & COFFEE (NEW!)
  // ========================================
  'fast_food': {
    'McDonald\'s': {
      'domain': 'mcdonalds.com',
      'keywords': ['mcdonalds', 'maccas', 'burger', 'fries', 'fast food'],
    },
    'Burger King': {
      'domain': 'bk.com',
      'keywords': ['burger', 'king', 'fast food', 'whopper'],
    },
    'KFC': {
      'domain': 'kfc.com',
      'keywords': ['kfc', 'chicken', 'fried', 'fast food', 'colonel'],
    },
    'Subway': {
      'domain': 'subway.com',
      'keywords': ['subway', 'sandwich', 'eat fresh', 'fast food'],
    },
    'Domino\'s': {
      'domain': 'dominos.com',
      'keywords': ['dominos', 'pizza', 'delivery', 'fast food'],
    },
    'Pizza Hut': {
      'domain': 'pizzahut.com',
      'keywords': ['pizza', 'hut', 'delivery', 'fast food'],
    },
    'Starbucks': {
      'domain': 'starbucks.com',
      'keywords': ['starbucks', 'coffee', 'latte', 'cafe', 'drink'],
    },
    'Costa Coffee': {
      'domain': 'costa.co.uk',
      'keywords': ['costa', 'coffee', 'cafe', 'drink', 'uk'],
    },
    'Dunkin\'': {
      'domain': 'dunkindonuts.com',
      'keywords': ['dunkin', 'donuts', 'coffee', 'breakfast'],
    },
    'Greggs': {
      'domain': 'greggs.co.uk',
      'keywords': ['greggs', 'bakery', 'sausage roll', 'uk', 'pastry'],
    },
    'Nando\'s': {
      'domain': 'nandos.co.uk',
      'keywords': ['nandos', 'chicken', 'peri peri', 'spicy'],
    },
    'Chipotle': {
      'domain': 'chipotle.com',
      'keywords': ['chipotle', 'mexican', 'burrito', 'fast food'],
    },
  },

  // ========================================
  // ENERGY & UTILITIES (UK)
  // ========================================
  'utilities_uk': {
    'British Gas': {
      'domain': 'britishgas.co.uk',
      'keywords': ['british', 'gas', 'energy', 'utility', 'heating', 'bill'],
    },
    'EDF Energy': {
      'domain': 'edfenergy.com',
      'keywords': ['edf', 'energy', 'electricity', 'utility'],
    },
    'E.ON': {
      'domain': 'eonenergy.com',
      'keywords': ['eon', 'energy', 'electricity', 'utility'],
    },
    'Scottish Power': {
      'domain': 'scottishpower.co.uk',
      'keywords': ['scottish', 'power', 'energy', 'utility'],
    },
    'OVO Energy': {
      'domain': 'ovoenergy.com',
      'keywords': ['ovo', 'energy', 'utility'],
    },
    'Bulb': {
      'domain': 'bulb.co.uk',
      'keywords': ['bulb', 'energy', 'utility'],
    },
    'Octopus Energy': {
      'domain': 'octopus.energy',
      'keywords': ['octopus', 'energy', 'utility', 'green'],
    },
    'Shell Energy': {
      'domain': 'shellenergy.co.uk',
      'keywords': ['shell', 'energy', 'utility'],
    },
    'Utilita': {
      'domain': 'utilita.co.uk',
      'keywords': ['utilita', 'energy', 'utility'],
    },
    'Thames Water': {
      'domain': 'thameswater.co.uk',
      'keywords': ['thames', 'water', 'utility', 'bill'],
    },
    'Severn Trent': {
      'domain': 'stwater.co.uk',
      'keywords': ['severn', 'trent', 'water', 'utility'],
    },
  },

  // ========================================
  // ENERGY & UTILITIES (US)
  // ========================================
  'utilities_us': {
    'Con Edison': {
      'domain': 'coned.com',
      'keywords': ['con', 'edison', 'energy', 'utility', 'electric'],
    },
    'PG&E': {
      'domain': 'pge.com',
      'keywords': ['pge', 'pacific', 'gas', 'electric', 'utility'],
    },
    'Duke Energy': {
      'domain': 'duke-energy.com',
      'keywords': ['duke', 'energy', 'utility'],
    },
    'Southern Company': {
      'domain': 'southerncompany.com',
      'keywords': ['southern', 'energy', 'utility'],
    },
    'Xcel Energy': {
      'domain': 'xcelenergy.com',
      'keywords': ['xcel', 'energy', 'utility'],
    },
    'Comcast': {
      'domain': 'xfinity.com',
      'keywords': ['comcast', 'utility', 'internet', 'cable'],
    },
  },

  // ========================================
  // MOBILE & BROADBAND (UK)
  // ========================================
  'mobile_uk': {
    'EE': {
      'domain': 'ee.co.uk',
      'keywords': ['ee', 'mobile', 'phone', 'network', 'broadband', 'internet'],
    },
    'O2': {
      'domain': 'o2.co.uk',
      'keywords': ['o2', 'mobile', 'phone', 'network'],
    },
    'Vodafone': {
      'domain': 'vodafone.co.uk',
      'keywords': ['vodafone', 'mobile', 'phone', 'network'],
    },
    'Three': {
      'domain': 'three.co.uk',
      'keywords': ['three', 'mobile', 'phone', 'network'],
    },
    'Sky': {
      'domain': 'sky.com',
      'keywords': ['sky', 'tv', 'broadband', 'mobile', 'internet'],
    },
    'Virgin Media': {
      'domain': 'virginmedia.com',
      'keywords': ['virgin', 'media', 'broadband', 'tv', 'internet'],
    },
    'BT': {
      'domain': 'bt.com',
      'keywords': ['bt', 'broadband', 'phone', 'internet', 'bill'],
    },
    'TalkTalk': {
      'domain': 'talktalk.co.uk',
      'keywords': ['talktalk', 'broadband', 'internet'],
    },
    'Plusnet': {
      'domain': 'plusnet.com',
      'keywords': ['plusnet', 'broadband', 'internet'],
    },
    'Hyperoptic': {
      'domain': 'hyperoptic.com',
      'keywords': ['hyperoptic', 'broadband', 'internet'],
    },
    'Giffgaff': {
      'domain': 'giffgaff.com',
      'keywords': ['giffgaff', 'mobile', 'phone'],
    },
    'Tesco Mobile': {
      'domain': 'tescomobile.com',
      'keywords': ['tesco', 'mobile', 'phone'],
    },
  },

  // ========================================
  // MOBILE & BROADBAND (US)
  // ========================================
  'mobile_us': {
    'Verizon': {
      'domain': 'verizon.com',
      'keywords': ['verizon', 'mobile', 'phone', 'network', 'internet'],
    },
    'AT&T': {
      'domain': 'att.com',
      'keywords': ['att', 'mobile', 'phone', 'network', 'internet'],
    },
    'T-Mobile': {
      'domain': 't-mobile.com',
      'keywords': ['tmobile', 'mobile', 'phone', 'network'],
    },
    'Sprint': {
      'domain': 'sprint.com',
      'keywords': ['sprint', 'mobile', 'phone'],
    },
    'Xfinity': {
      'domain': 'xfinity.com',
      'keywords': ['xfinity', 'internet', 'broadband', 'comcast'],
    },
    'Spectrum': {
      'domain': 'spectrum.com',
      'keywords': ['spectrum', 'internet', 'broadband'],
    },
  },

  // ========================================
  // INSURANCE (UK)
  // ========================================
  'insurance_uk': {
    'Admiral': {
      'domain': 'admiral.com',
      'keywords': ['admiral', 'insurance', 'car', 'home'],
    },
    'Aviva': {
      'domain': 'aviva.co.uk',
      'keywords': ['aviva', 'insurance', 'car', 'home', 'life'],
    },
    'Direct Line': {
      'domain': 'directline.com',
      'keywords': ['direct', 'line', 'insurance', 'car'],
    },
    'Churchill': {
      'domain': 'churchill.com',
      'keywords': ['churchill', 'insurance', 'car', 'dog'],
    },
    'Hastings Direct': {
      'domain': 'hastingsdirect.com',
      'keywords': ['hastings', 'insurance', 'car'],
    },
    'LV=': {
      'domain': 'lv.com',
      'keywords': ['lv', 'insurance', 'car', 'home'],
    },
    'The AA': {
      'domain': 'theaa.com',
      'keywords': ['aa', 'insurance', 'breakdown', 'car'],
    },
    'RAC': {
      'domain': 'rac.co.uk',
      'keywords': ['rac', 'breakdown', 'insurance', 'car'],
    },
    'Bupa': {
      'domain': 'bupa.co.uk',
      'keywords': ['bupa', 'health', 'insurance', 'medical'],
    },
    'AXA': {
      'domain': 'axa.co.uk',
      'keywords': ['axa', 'insurance', 'health', 'car'],
    },
  },

  // ========================================
  // INSURANCE (US)
  // ========================================
  'insurance_us': {
    'Geico': {
      'domain': 'geico.com',
      'keywords': ['geico', 'insurance', 'car', 'auto', 'lizard'],
    },
    'State Farm': {
      'domain': 'statefarm.com',
      'keywords': ['state', 'farm', 'insurance'],
    },
    'Allstate': {
      'domain': 'allstate.com',
      'keywords': ['allstate', 'insurance', 'car'],
    },
    'Progressive': {
      'domain': 'progressive.com',
      'keywords': ['progressive', 'insurance', 'car'],
    },
    'Liberty Mutual': {
      'domain': 'libertymutual.com',
      'keywords': ['liberty', 'mutual', 'insurance'],
    },
    'USAA': {
      'domain': 'usaa.com',
      'keywords': ['usaa', 'insurance', 'military'],
    },
    'Aetna': {
      'domain': 'aetna.com',
      'keywords': ['aetna', 'health', 'insurance'],
    },
    'UnitedHealthcare': {
      'domain': 'uhc.com',
      'keywords': ['united', 'healthcare', 'insurance'],
    },
  },

  // ========================================
  // FITNESS & GYM
  // ========================================
  'fitness': {
    'PureGym': {
      'domain': 'puregym.com',
      'keywords': ['pure', 'gym', 'fitness', 'exercise'],
    },
    'The Gym Group': {
      'domain': 'thegymgroup.com',
      'keywords': ['gym', 'group', 'fitness'],
    },
    'David Lloyd': {
      'domain': 'davidlloyd.co.uk',
      'keywords': ['david', 'lloyd', 'gym', 'fitness', 'club'],
    },
    'Nuffield Health': {
      'domain': 'nuffieldhealth.com',
      'keywords': ['nuffield', 'health', 'gym', 'fitness'],
    },
    'Planet Fitness': {
      'domain': 'planetfitness.com',
      'keywords': ['planet', 'fitness', 'gym'],
    },
    'LA Fitness': {
      'domain': 'lafitness.com',
      'keywords': ['la', 'fitness', 'gym'],
    },
    'Gold\'s Gym': {
      'domain': 'goldsgym.com',
      'keywords': ['golds', 'gym', 'fitness'],
    },
    'Peloton': {
      'domain': 'onepeloton.com',
      'keywords': ['peloton', 'fitness', 'cycling', 'bike'],
    },
    'Strava': {
      'domain': 'strava.com',
      'keywords': ['strava', 'fitness', 'running', 'cycling', 'app'],
    },
    'Fitbit': {
      'domain': 'fitbit.com',
      'keywords': ['fitbit', 'fitness', 'tracker', 'health'],
    },
  },

  // ========================================
  // FOOD DELIVERY
  // ========================================
  'food_delivery': {
    'Deliveroo': {
      'domain': 'deliveroo.co.uk',
      'keywords': ['deliveroo', 'food', 'delivery', 'restaurant'],
    },
    'Uber Eats': {
      'domain': 'ubereats.com',
      'keywords': ['uber', 'eats', 'food', 'delivery'],
    },
    'Just Eat': {
      'domain': 'just-eat.co.uk',
      'keywords': ['just', 'eat', 'food', 'delivery'],
    },
    'DoorDash': {
      'domain': 'doordash.com',
      'keywords': ['doordash', 'food', 'delivery'],
    },
    'Grubhub': {
      'domain': 'grubhub.com',
      'keywords': ['grubhub', 'food', 'delivery'],
    },
    'HelloFresh': {
      'domain': 'hellofresh.com',
      'keywords': ['hello', 'fresh', 'food', 'meal', 'kit'],
    },
    'Gousto': {
      'domain': 'gousto.co.uk',
      'keywords': ['gousto', 'food', 'meal', 'kit'],
    },
  },

  // ========================================
  // RETAIL (UK)
  // ========================================
  'retail_uk': {
    'Tesco': {
      'domain': 'tesco.com',
      'keywords': ['tesco', 'supermarket', 'grocery', 'shopping', 'food'],
    },
    'Sainsbury\'s': {
      'domain': 'sainsburys.co.uk',
      'keywords': ['sainsburys', 'supermarket', 'grocery'],
    },
    'ASDA': {
      'domain': 'asda.com',
      'keywords': ['asda', 'supermarket', 'grocery'],
    },
    'Morrisons': {
      'domain': 'morrisons.com',
      'keywords': ['morrisons', 'supermarket', 'grocery'],
    },
    'Waitrose': {
      'domain': 'waitrose.com',
      'keywords': ['waitrose', 'supermarket', 'grocery', 'premium'],
    },
    'Aldi': {
      'domain': 'aldi.co.uk',
      'keywords': ['aldi', 'supermarket', 'grocery', 'budget'],
    },
    'Lidl': {
      'domain': 'lidl.co.uk',
      'keywords': ['lidl', 'supermarket', 'grocery', 'budget'],
    },
    'Marks & Spencer': {
      'domain': 'marksandspencer.com',
      'keywords': ['marks', 'spencer', 'ms', 'retail', 'food'],
    },
    'John Lewis': {
      'domain': 'johnlewis.com',
      'keywords': ['john', 'lewis', 'retail', 'department', 'home'],
    },
    'Argos': {
      'domain': 'argos.co.uk',
      'keywords': ['argos', 'retail', 'shopping', 'catalogue'],
    },
    'Boots': {
      'domain': 'boots.com',
      'keywords': ['boots', 'pharmacy', 'health', 'beauty'],
    },
    'Superdrug': {
      'domain': 'superdrug.com',
      'keywords': ['superdrug', 'pharmacy', 'beauty'],
    },
    'Currys': {
      'domain': 'currys.co.uk',
      'keywords': ['currys', 'tech', 'electronics', 'pc world'],
    },
    'IKEA': {
      'domain': 'ikea.com',
      'keywords': ['ikea', 'furniture', 'home', 'swedish'],
    },
  },

  // ========================================
  // RETAIL (US)
  // ========================================
  'retail_us': {
    'Walmart': {
      'domain': 'walmart.com',
      'keywords': ['walmart', 'supermarket', 'retail', 'shopping'],
    },
    'Target': {
      'domain': 'target.com',
      'keywords': ['target', 'retail', 'shopping', 'bullseye'],
    },
    'Costco': {
      'domain': 'costco.com',
      'keywords': ['costco', 'wholesale', 'shopping', 'bulk'],
    },
    'Whole Foods': {
      'domain': 'wholefoodsmarket.com',
      'keywords': ['whole', 'foods', 'grocery', 'organic', 'amazon'],
    },
    'Trader Joe\'s': {
      'domain': 'traderjoes.com',
      'keywords': ['trader', 'joes', 'grocery', 'market'],
    },
    'CVS': {
      'domain': 'cvs.com',
      'keywords': ['cvs', 'pharmacy', 'health'],
    },
    'Walgreens': {
      'domain': 'walgreens.com',
      'keywords': ['walgreens', 'pharmacy', 'health'],
    },
    'Best Buy': {
      'domain': 'bestbuy.com',
      'keywords': ['best', 'buy', 'electronics', 'tech'],
    },
    'Home Depot': {
      'domain': 'homedepot.com',
      'keywords': ['home', 'depot', 'diy', 'hardware'],
    },
    'Amazon': {
      'domain': 'amazon.com',
      'keywords': ['amazon', 'shopping', 'online', 'retail'],
    },
  },

  // ========================================
  // BANKS (UK)
  // ========================================
  'banks_uk': {
    'Barclays': {
      'domain': 'barclays.co.uk',
      'keywords': ['barclays', 'bank', 'banking', 'finance'],
    },
    'HSBC': {
      'domain': 'hsbc.co.uk',
      'keywords': ['hsbc', 'bank', 'banking'],
    },
    'Lloyds': {
      'domain': 'lloydsbank.com',
      'keywords': ['lloyds', 'bank', 'banking', 'horse'],
    },
    'NatWest': {
      'domain': 'natwest.com',
      'keywords': ['natwest', 'bank', 'banking'],
    },
    'Santander': {
      'domain': 'santander.co.uk',
      'keywords': ['santander', 'bank', 'banking'],
    },
    'Halifax': {
      'domain': 'halifax.co.uk',
      'keywords': ['halifax', 'bank', 'banking'],
    },
    'Nationwide': {
      'domain': 'nationwide.co.uk',
      'keywords': ['nationwide', 'building', 'society', 'bank'],
    },
    'TSB': {
      'domain': 'tsb.co.uk',
      'keywords': ['tsb', 'bank', 'banking'],
    },
    'Monzo': {
      'domain': 'monzo.com',
      'keywords': ['monzo', 'bank', 'digital', 'banking', 'coral'],
    },
    'Revolut': {
      'domain': 'revolut.com',
      'keywords': ['revolut', 'bank', 'digital', 'banking'],
    },
    'Starling': {
      'domain': 'starlingbank.com',
      'keywords': ['starling', 'bank', 'digital'],
    },
    'Chase UK': {
      'domain': 'chase.co.uk',
      'keywords': ['chase', 'bank', 'digital', 'uk'],
    },
  },

  // ========================================
  // BANKS (US)
  // ========================================
  'banks_us': {
    'Chase': {
      'domain': 'chase.com',
      'keywords': ['chase', 'bank', 'banking', 'morgan'],
    },
    'Bank of America': {
      'domain': 'bankofamerica.com',
      'keywords': ['bank', 'america', 'boa', 'banking'],
    },
    'Wells Fargo': {
      'domain': 'wellsfargo.com',
      'keywords': ['wells', 'fargo', 'bank', 'banking'],
    },
    'Citibank': {
      'domain': 'citibank.com',
      'keywords': ['citi', 'bank', 'banking'],
    },
    'Capital One': {
      'domain': 'capitalone.com',
      'keywords': ['capital', 'one', 'bank', 'credit'],
    },
    'US Bank': {
      'domain': 'usbank.com',
      'keywords': ['us', 'bank', 'banking'],
    },
    'Goldman Sachs': {
      'domain': 'goldmansachs.com',
      'keywords': ['goldman', 'sachs', 'bank', 'investment'],
    },
  },

  // ========================================
  // TRANSPORT & AUTO
  // ========================================
  'transport': {
    'Uber': {
      'domain': 'uber.com',
      'keywords': ['uber', 'taxi', 'ride', 'transport', 'car'],
    },
    'Lyft': {
      'domain': 'lyft.com',
      'keywords': ['lyft', 'ride', 'transport', 'taxi'],
    },
    'Bolt': {
      'domain': 'bolt.eu',
      'keywords': ['bolt', 'taxi', 'ride'],
    },
    'Shell': {
      'domain': 'shell.com',
      'keywords': ['shell', 'petrol', 'gas', 'fuel'],
    },
    'BP': {
      'domain': 'bp.com',
      'keywords': ['bp', 'petrol', 'gas', 'fuel'],
    },
    'Esso': {
      'domain': 'esso.co.uk',
      'keywords': ['esso', 'petrol', 'gas', 'fuel'],
    },
    'Texaco': {
      'domain': 'texaco.com',
      'keywords': ['texaco', 'petrol', 'gas', 'fuel'],
    },
    'Tesla': {
      'domain': 'tesla.com',
      'keywords': ['tesla', 'car', 'electric', 'ev', 'musk'],
    },
    'Ford': {
      'domain': 'ford.com',
      'keywords': ['ford', 'car', 'auto'],
    },
    'Toyota': {
      'domain': 'toyota.com',
      'keywords': ['toyota', 'car', 'auto'],
    },
    'BMW': {
      'domain': 'bmw.com',
      'keywords': ['bmw', 'car', 'auto'],
    },
    'Zipcar': {
      'domain': 'zipcar.com',
      'keywords': ['zipcar', 'car', 'rental', 'sharing'],
    },
    'TFL': {
      'domain': 'tfl.gov.uk',
      'keywords': ['tfl', 'transport', 'london', 'tube', 'bus'],
    },
  },

  // ========================================
  // GAMING & SOFTWARE
  // ========================================
  'gaming': {
    'PlayStation': {
      'domain': 'playstation.com',
      'keywords': ['playstation', 'ps', 'ps5', 'gaming', 'sony'],
    },
    'Xbox': {
      'domain': 'xbox.com',
      'keywords': ['xbox', 'gaming', 'microsoft', 'console'],
    },
    'Nintendo': {
      'domain': 'nintendo.com',
      'keywords': ['nintendo', 'switch', 'gaming', 'mario'],
    },
    'Steam': {
      'domain': 'steampowered.com',
      'keywords': ['steam', 'gaming', 'pc', 'games', 'valve'],
    },
    'Epic Games': {
      'domain': 'epicgames.com',
      'keywords': ['epic', 'games', 'gaming', 'fortnite'],
    },
    'Roblox': {
      'domain': 'roblox.com',
      'keywords': ['roblox', 'game', 'kids'],
    },
    'EA': {
      'domain': 'ea.com',
      'keywords': ['ea', 'electronic', 'arts', 'gaming', 'fifa'],
    },
    'Ubisoft': {
      'domain': 'ubisoft.com',
      'keywords': ['ubisoft', 'gaming', 'games'],
    },
  },

  // ========================================
  // NEWS & MEDIA (NEW!)
  // ========================================
  'news': {
    'BBC': {
      'domain': 'bbc.co.uk',
      'keywords': ['bbc', 'news', 'tv', 'radio', 'uk'],
    },
    'CNN': {
      'domain': 'cnn.com',
      'keywords': ['cnn', 'news', 'usa', 'tv'],
    },
    'The Guardian': {
      'domain': 'theguardian.com',
      'keywords': ['guardian', 'news', 'newspaper'],
    },
    'New York Times': {
      'domain': 'nytimes.com',
      'keywords': ['nyt', 'new york times', 'news', 'paper'],
    },
    'Fox News': {
      'domain': 'foxnews.com',
      'keywords': ['fox', 'news', 'tv'],
    },
    'Sky News': {
      'domain': 'news.sky.com',
      'keywords': ['sky', 'news', 'uk'],
    },
    'Financial Times': {
      'domain': 'ft.com',
      'keywords': ['ft', 'financial', 'times', 'business', 'news'],
    },
  },
};
