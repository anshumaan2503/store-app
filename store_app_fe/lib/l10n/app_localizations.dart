
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String>? _localizedStrings;

  // Future<bool> load() async {
  //   try {
  //     String jsonString =
  //         await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
  //     Map<String, dynamic> jsonMap = json.decode(jsonString);

  //     _localizedStrings = jsonMap.map((key, value) {
  //       return MapEntry(key, value.toString());
  //     });
  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  String translate(String key) {
    if (_localizedStrings == null) {
      return 'Localized strings not loaded';
    }
    if (!_localizedStrings!.containsKey(key)) {
      return 'Key not found';
    }
    return _localizedStrings![key] ?? 'Key not found';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    // await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
