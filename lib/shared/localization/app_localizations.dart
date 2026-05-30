import 'package:flutter/widgets.dart';

import '../../features/settings/settings_models.dart';

class SajhaLocalizationScope extends InheritedWidget {
  const SajhaLocalizationScope({
    required this.language,
    required super.child,
    super.key,
  });

  final AppLanguage language;

  static SajhaLocalizationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SajhaLocalizationScope>();
  }

  static SajhaLocalizationScope of(BuildContext context) {
    return maybeOf(context) ??
        const SajhaLocalizationScope(
          language: AppLanguage.english,
          child: SizedBox.shrink(),
        );
  }

  String text(String source) {
    if (language == AppLanguage.english) {
      return source;
    }
    return _nepaliText[source] ?? source;
  }

  @override
  bool updateShouldNotify(SajhaLocalizationScope oldWidget) {
    return language != oldWidget.language;
  }
}

extension SajhaLocalizedText on BuildContext {
  String t(String source) => SajhaLocalizationScope.of(this).text(source);
}

const _nepaliText = <String, String>{
  'Home': 'गृह',
  'Groups': 'समूह',
  'Connections': 'सम्पर्क',
  'Send Gift': 'उपहार पठाउनुहोस्',
  'Settings': 'सेटिङहरू',
  'Namaste': 'नमस्ते',
  'Here’s your shared balance summary': 'तपाईंको साझा खर्च सारांश',
  'Account': 'खाता',
  'Edit Profile': 'प्रोफाइल सम्पादन',
  'Logout': 'लगआउट',
  'Return to login on this device.': 'यो डिभाइसमा लगइनमा फर्कनुहोस्।',
  'Delete Account': 'खाता मेटाउनुहोस्',
  'Available only after every balance is settled.':
      'सबै ब्यालेन्स मिलाएपछि मात्र उपलब्ध हुन्छ।',
  'Settle balances first': 'पहिले ब्यालेन्स मिलाउनुहोस्',
  'You cannot delete your account while money is unsettled.':
      'पैसा नमिलेसम्म खाता मेटाउन सकिँदैन।',
  'Delete account?': 'खाता मेटाउने?',
  'This removes your saved profile and signs you out on this device.':
      'यसले तपाईंको सुरक्षित प्रोफाइल हटाएर यो डिभाइसबाट साइन आउट गर्छ।',
  'Delete': 'मेटाउनुहोस्',
  'OK': 'ठीक छ',
  'Cancel': 'रद्द',
  'Privacy & Connections': 'गोपनीयता र सम्पर्क',
  'Connection Requests': 'सम्पर्क अनुरोध',
  'Blocked Users': 'ब्लक गरिएका प्रयोगकर्ता',
  'Groups & Expenses': 'समूह र खर्च',
  'Default Split': 'पूर्वनिर्धारित बाँडफाँट',
  'OCR Review': 'OCR समीक्षा',
  'Show Rounding Note': 'राउन्डिङ नोट देखाउनुहोस्',
  'Payments': 'भुक्तानी',
  'Confirm Before Payment': 'भुक्तानी अघि पुष्टि',
  'Settlement Nudges': 'सेटलमेन्ट सम्झना',
  'Default Reminder': 'पूर्वनिर्धारित सम्झना',
  'Digital Dhukuti': 'डिजिटल ढुकुटी',
  'Contribution Reminders': 'योगदान सम्झना',
  'At-Risk Alerts': 'जोखिम सूचना',
  'Notifications': 'सूचनाहरू',
  'Choose which Sajha Kharcha events appear in your notification center.':
      'तपाईंको सूचना केन्द्रमा देखिने Sajha Kharcha घटनाहरू छान्नुहोस्।',
  'Notification Types': 'सूचना प्रकार',
  'Manage Notifications': 'सूचना व्यवस्थापन',
  'Appearance': 'देखावट',
  'Theme': 'थिम',
  'Language': 'भाषा',
  'Help & About': 'मद्दत र जानकारी',
  'How Sajha Kharcha Works': 'Sajha Kharcha कसरी काम गर्छ',
  'About Sajha Kharcha': 'Sajha Kharcha बारे',
  'Terms & Privacy': 'सर्त र गोपनीयता',
  'Version 1.0': 'संस्करण १.०',
  'Light': 'उज्यालो',
  'Dark': 'अँध्यारो',
  'System': 'सिस्टम',
  'English': 'English',
  'नेपाली': 'नेपाली',
  'Everyone': 'सबै',
  'Contacts only': 'सम्पर्क मात्र',
  'QR invite only': 'QR निमन्त्रणा मात्र',
  'Equal Split': 'बराबर बाँडफाँट',
  'Exact Amount': 'ठ्याक्कै रकम',
  'Always review': 'सधैं समीक्षा',
  'Low confidence only': 'कम भरोसा मात्र',
  'Auto-accept trusted receipts': 'विश्वसनीय बिल स्वतः स्वीकार',
  'None': 'छैन',
  'Daily': 'दैनिक',
  'Every 2 days': 'हरेक २ दिन',
  'Weekly': 'साप्ताहिक',
  'Language updated': 'भाषा परिवर्तन भयो',
};
