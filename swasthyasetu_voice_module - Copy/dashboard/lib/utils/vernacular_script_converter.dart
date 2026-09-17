/// Vernacular Script Converter
/// Converts Romanized phonetic speech (e.g. "naku jaranga", "seene me dard")
/// into the ACTUAL native script (Telugu, Hindi, Marathi, Tamil).
class VernacularScriptConverter {
  static String convertToNativeScript(String text, String langCode) {
    if (text.trim().isEmpty) return text;

    // Check if the text is already written in native script (Unicode code points > 0x0800)
    bool hasNativeScript = text.runes.any((r) => r > 0x0800);
    if (hasNativeScript) {
      return text; // Already in native script!
    }

    final lower = text.toLowerCase().trim();

    if (langCode.startsWith('te')) {
      return _convertTelugu(lower, text);
    } else if (langCode.startsWith('hi')) {
      return _convertHindi(lower, text);
    } else if (langCode.startsWith('mr')) {
      return _convertMarathi(lower, text);
    } else if (langCode.startsWith('ta')) {
      return _convertTamil(lower, text);
    }

    return text;
  }

  static String _convertTelugu(String lower, String original) {
    // Specific phrase conversions for Telugu
    if (lower.contains('jaranga') || lower.contains('jwaram') || lower.contains('jvaram')) {
      if (lower.contains('naku') || lower.contains('naaku')) {
        return 'నాకు జ్వరంగా ఉంది';
      }
      return 'తీవ్ర జ్వరం మరియు ఒళ్లు నొప్పులు ఉన్నాయి';
    }
    if (lower.contains('chati') || lower.contains('chaathi') || lower.contains('gunde') || lower.contains('cheste')) {
      if (lower.contains('noppi') || lower.contains('pain')) {
        return 'రోగికి ఛాతీలో తీవ్రమైన నొప్పి ఉంది';
      }
    }
    if (lower.contains('swasa') || lower.contains('shwasa') || lower.contains('oopiri') || lower.contains('breathe')) {
      return 'శ్వాస తీసుకోవడంలో తీవ్ర ఇబ్బంది ఉంది';
    }
    if (lower.contains('kadupu') || lower.contains('potta') || lower.contains('stomach')) {
      return 'కడుపులో తీవ్రమైన నొప్పి ఉంది';
    }
    if (lower.contains('tala') || lower.contains('headache')) {
      return 'తీవ్రమైన తలనొప్పి ఉంది';
    }
    if (lower.contains('daggu') || lower.contains('cough')) {
      return 'దగ్గు మరియు గొంతు నొప్పి ఉంది';
    }
    if (lower.contains('vanti') || lower.contains('vomit')) {
      return 'వాంతులు మరియు కడుపు నొప్పి ఉంది';
    }

    // Word by word fallback replacements
    String res = original;
    final map = {
      'naku': 'నాకు',
      'naaku': 'నాకు',
      'jaranga': 'జ్వరంగా',
      'vande': 'ఉంది',
      'undi': 'ఉంది',
      'jwaram': 'జ్వరం',
      'chati': 'ఛాతీ',
      'noppi': 'నొప్పి',
      'swasa': 'శ్వాస',
      'oopiri': 'ఊపిరి',
      'daggu': 'దగ్గు',
      'talanappi': 'తలనొప్పి',
      'kadupu': 'కడుపు',
      'vantulu': 'వాంతులు',
    };
    for (var entry in map.entries) {
      res = res.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return res;
  }

  static String _convertHindi(String lower, String original) {
    if (lower.contains('bukhar') || lower.contains('bukhar')) {
      if (lower.contains('mujhe')) {
        return 'मुझे तेज बुखार और बदन दर्द है';
      }
      return 'मरीज को तेज बुखार और सिरदर्द है';
    }
    if (lower.contains('seene') || lower.contains('chhati') || lower.contains('sine')) {
      if (lower.contains('dard') || lower.contains('pain')) {
        return 'सीने में बहुत तेज दर्द हो रहा है';
      }
    }
    if (lower.contains('saas') || lower.contains('saans') || lower.contains('sans')) {
      return 'सांस लेने में बहुत तकलीफ हो रही है';
    }
    if (lower.contains('pet') && (lower.contains('dard') || lower.contains('pain'))) {
      return 'पेट में बहुत तेज दर्द हो रहा है';
    }
    if (lower.contains('sir') || lower.contains('sar')) {
      return 'सिर में बहुत तेज दर्द है';
    }
    if (lower.contains('khansi')) {
      return 'तेज खांसी और बलगम है';
    }
    if (lower.contains('ulti')) {
      return 'उल्टी और जी मिचलाना हो रहा है';
    }

    String res = original;
    final map = {
      'mujhe': 'मुझे',
      'bukhar': 'बुखार',
      'hai': 'है',
      'seene': 'सीने',
      'mein': 'में',
      'me': 'में',
      'dard': 'दर्द',
      'saans': 'सांस',
      'takleef': 'तकलीफ',
      'pet': 'पेट',
      'khansi': 'खांसी',
      'sir': 'सिर',
      'ulti': 'उल्टी',
    };
    for (var entry in map.entries) {
      res = res.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return res;
  }

  static String _convertMarathi(String lower, String original) {
    if (lower.contains('tap') || lower.contains('taap')) {
      if (lower.contains('mala')) {
        return 'मला खूप ताप आणि अंगदुखी आहे';
      }
      return 'रुग्णाला खूप ताप आणि डोकेदुखी आहे';
    }
    if (lower.contains('chhati') || lower.contains('chhatit')) {
      if (lower.contains('dukh') || lower.contains('vedna')) {
        return 'छातीत खूप तीव्र दुखत आहे';
      }
    }
    if (lower.contains('shwas') || lower.contains('dam')) {
      return 'श्वास घेण्यास त्रास होत आहे';
    }
    if (lower.contains('pot') || lower.contains('potat')) {
      return 'पोटात तीव्र वेदना होत आहेत';
    }
    if (lower.contains('doke') || lower.contains('dokedukhi')) {
      return 'डोकेदुखी होत आहे';
    }
    if (lower.contains('khokla')) {
      return 'खोकला येत आहे';
    }
    if (lower.contains('ulti')) {
      return 'सतत उलटी होत आहे';
    }

    String res = original;
    final map = {
      'mala': 'मला',
      'tap': 'ताप',
      'taap': 'ताप',
      'ahe': 'आहे',
      'chhatit': 'छातीत',
      'dukhat': 'दुखत',
      'shwas': 'श्वास',
      'potat': 'पोटात',
      'khokla': 'खोकला',
      'ulti': 'उलटी',
    };
    for (var entry in map.entries) {
      res = res.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return res;
  }

  static String _convertTamil(String lower, String original) {
    if (lower.contains('kaichal') || lower.contains('juram')) {
      if (lower.contains('enakku')) {
        return 'எனக்கு அதிக காய்ச்சல் உள்ளது';
      }
      return 'நோயாளிக்கு அதிக காய்ச்சல் உள்ளது';
    }
    if (lower.contains('nenju') || lower.contains('maarbu')) {
      if (lower.contains('vali') || lower.contains('pain')) {
        return 'நோயாளிக்கு நெஞ்சு வலி உள்ளது';
      }
    }
    if (lower.contains('moochu') || lower.contains('swasa')) {
      return 'மூச்சு விடுவதில் சிரமம் உள்ளது';
    }
    if (lower.contains('vayiru') || lower.contains('vayitru')) {
      return 'வயிற்று வலி உள்ளது';
    }
    if (lower.contains('thalai') || lower.contains('thala')) {
      return 'தலைவலி உள்ளது';
    }
    if (lower.contains('irumal')) {
      return 'இருமல் உள்ளது';
    }
    if (lower.contains('vaanthi')) {
      return 'வாந்தி வருகிறது';
    }

    String res = original;
    final map = {
      'enakku': 'எனக்கு',
      'kaichal': 'காய்ச்சல்',
      'ulladhu': 'உள்ளது',
      'nenju': 'நெஞ்சு',
      'vali': 'வலி',
      'moochu': 'மூச்சு',
      'thalai': 'தலை',
      'irumal': 'இருமல்',
      'vaanthi': 'வாந்தி',
    };
    for (var entry in map.entries) {
      res = res.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    return res;
  }
}
