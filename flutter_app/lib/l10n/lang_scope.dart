import 'package:flutter/widgets.dart';
import 'app_strings.dart';

/// Figma prototype languages: English, Kannada, Hindi, Telugu, Tamil.
enum AppLang { en, kn, hi, te, ta }

extension AppLangMeta on AppLang {
  String get code => name;

  String get displayName =>
      FigmaStrings.languageNames[code] ?? code.toUpperCase();
}

/// App-wide language state. Held by [NetraAiApp], read via [BuildContext.tr].
class LangController extends ValueNotifier<AppLang> {
  LangController() : super(AppLang.en);
}

class LangScope extends InheritedNotifier<LangController> {
  const LangScope({
    super.key,
    required LangController super.notifier,
    required super.child,
  });

  static AppLang langOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LangScope>()
          ?.notifier
          ?.value ??
      AppLang.en;

  static void setLang(BuildContext context, AppLang lang) {
    context.dependOnInheritedWidgetOfExactType<LangScope>()?.notifier?.value =
        lang;
  }
}

/// `context.tr('dash_title')` — Figma string in the active language,
/// falling back to English, then to the key itself.
extension TrExt on BuildContext {
  String tr(String key) {
    final code = LangScope.langOf(this).code;
    return FigmaStrings.values[code]?[key] ??
        FigmaStrings.values['en']?[key] ??
        key;
  }
}
