import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Device-local language; user-entered names and notes are kept as entered.
abstract final class AppLanguage {
  static String _code = 'en';
  static String get code => _code;
  static void use(String code) {
    _code = code == 'af' ? 'af' : 'en';
    Intl.defaultLocale = _code;
  }
}

String tr(String text, {String? language}) {
  if ((language ?? AppLanguage.code) != 'af' || text.isEmpty) return text;
  final exact = afrikaans[text];
  if (exact != null) return exact;
  for (final entry in _patterns) {
    final match = entry.pattern.firstMatch(text);
    if (match == null) continue;
    var translated = entry.translation;
    for (var i = 0; i < entry.parameters.length; i++) {
      translated = translated.replaceAll(
        '{${entry.parameters[i]}}',
        match.group(i + 1)!,
      );
    }
    return translated;
  }
  for (final separator in ['\n', ' · ', ', ']) {
    if (text.contains(separator)) {
      return text
          .split(separator)
          .map((part) => tr(part, language: language))
          .join(separator);
    }
  }
  return text;
}

final _patterns = [
  for (final entry in afrikaans.entries)
    if (entry.key.contains('{')) _TranslationPattern(entry.key, entry.value),
]..sort((a, b) => b.specificity.compareTo(a.specificity));

class _TranslationPattern {
  late final RegExp pattern;
  final String translation;
  final List<String> parameters = [];
  final int specificity;
  _TranslationPattern(String source, this.translation)
    : specificity = source.replaceAll(RegExp(r'\{[^}]+\}'), '').length {
    final placeholder = RegExp(r'\{([a-zA-Z]+)\}');
    var offset = 0;
    var expression = '^';
    for (final match in placeholder.allMatches(source)) {
      expression += RegExp.escape(source.substring(offset, match.start));
      expression += '(.*?)';
      parameters.add(match.group(1)!);
      offset = match.end;
    }
    expression += '${RegExp.escape(source.substring(offset))}\$';
    pattern = RegExp(expression, dotAll: true);
  }
}

/// Const-friendly localized text keeps existing screens and dialog styles.
class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  }) : localize = true;
  const LText.raw(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  }) : localize = false;
  final bool localize;
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => Text(
    localize
        ? tr(data, language: Localizations.localeOf(context).languageCode)
        : data,
    style: style,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
    softWrap: softWrap,
  );
}

class LIconButton extends StatelessWidget {
  const LIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: icon,
    onPressed: onPressed,
    tooltip: tooltip == null
        ? null
        : tr(tooltip!, language: Localizations.localeOf(context).languageCode),
  );
}

class LInputDecoration extends InputDecoration {
  const LInputDecoration({
    super.labelText,
    super.hintText,
    super.prefixIcon,
    super.suffixIcon,
    super.contentPadding,
    super.border,
    super.enabledBorder,
  });
  @override
  String? get labelText =>
      super.labelText == null ? null : tr(super.labelText!);
  @override
  String? get hintText => super.hintText == null ? null : tr(super.hintText!);
}

class LTextFormField extends TextFormField {
  LTextFormField({
    super.key,
    super.controller,
    super.autofocus,
    super.maxLength,
    super.maxLines,
    super.textCapitalization,
    super.decoration,
    super.onFieldSubmitted,
    FormFieldValidator<String>? validator,
  }) : super(
         validator: validator == null
             ? null
             : (value) {
                 final error = validator(value);
                 return error == null ? null : tr(error);
               },
       );
}

// Exact labels and explicit templates. Captured values are never translated,
// so baby names, caregiver names, activity names and notes stay unchanged.
const afrikaans = <String, String>{
  'What’s new': 'Wat is nuut',
  'Version {version}': 'Weergawe {version}',
  'Got it': 'Goed so',
  'Nighttime': 'Nagtyd',
  'App updates are available on Android.':
      'Appopdaterings is op Android beskikbaar.',
  'App updates': 'Appopdaterings',
  'New update available: {version}': 'Nuwe opdatering beskikbaar: {version}',
  'Update': 'Dateer op',
  'Check for updates': 'Kyk vir opdaterings',
  'Checking for updates…': 'Kyk tans vir opdaterings…',
  'Downloading: {progress}%': 'Laai af: {progress}%',
  'No releases available yet.': 'Nog geen vrystellings beskikbaar nie.',
  'No compatible update available.':
      'Geen versoenbare opdatering beskikbaar nie.',
  'Could not check for updates. Try again when you are online.':
      'Kon nie vir opdaterings kyk nie. Probeer weer wanneer jy aanlyn is.',
  'Download from GitHub, then confirm installation in Android. Your logs stay on this device.': 'Laai van GitHub af en bevestig dan die installering in Android. Jou logboek bly op hierdie toestel.',
  'Confirm the update in Android. If cancelled, tap Update to try again.': 'Bevestig die opdatering in Android. Indien gekanselleer, tik Dateer op om weer te probeer.',
  'Allow updates from Baby Log, then return and tap Update again.': 'Laat opdaterings van Baby Log toe, keer dan terug en tik weer Dateer op.',
  'Could not install the update. Please try again.':
      'Kon nie die opdatering installeer nie. Probeer asseblief weer.',
  'Language': 'Taal',
  'Search settings': 'Soek instellings',
  'Clear search': 'Maak soektog skoon',
  'No settings found. Try a different search.':
      'Geen instellings gevind nie. Probeer ’n ander soektog.',
  'English': 'English',
  'Afrikaans': 'Afrikaans',
  'Choose your language': 'Kies jou taal',
  'You can change this later in Settings.':
      'Jy kan dit later in Instellings verander.',
  'Today': 'Vandag',
  'Yesterday': 'Gister',
  'History': 'Geskiedenis',
  'Pills': 'Pille',
  'Routines': 'Roetines',
  'Settings': 'Instellings',
  'Baby': 'Baba',
  'your baby': 'jou baba',
  'feed': 'voeding',
  'feeds': 'voedings',
  'nappy': 'doek',
  'nappies': 'doeke',
  'pill': 'pil',
  'pills': 'pille',
  'routine': 'roetine',
  'routines': 'roetines',
  'Baby Log': 'Baby Log',
  'Save': 'Stoor',
  'Cancel': 'Kanselleer',
  'Close': 'Maak toe',
  'Clear': 'Maak skoon',
  'Edit': 'Wysig',
  'Delete': 'Verwyder',
  'Undo': 'Ontdoen',
  'Next': 'Volgende',
  'Back': 'Terug',
  'Skip': 'Slaan oor',
  'Off': 'Af',
  'On': 'Aan',
  'Done': 'Klaar',
  'Date': 'Datum',
  'Time': 'Tyd',
  'Get started': 'Begin',
  'Start using Baby Log': 'Begin Baby Log gebruik',
  'Welcome to Baby Log': 'Welkom by Baby Log',
  'Everything about the little one in one place, in a single tap.':
      'Alles oor jou kleinding op een plek, met een tik.',
  'Feeds': 'Voedings',
  'Nappies': 'Doeke',
  'Your pills': 'Jou pille',
  'Shared': 'Gedeel',
  'Which side, when and for how long': 'Watter kant, wanneer en hoe lank',
  'Pee, poo or both, with daily totals':
      'Piepie, poef of albei, met daaglikse totale',
  'Dose times worked out, with alarms': 'Dosistye bereken, met wekkers',
  'Both phones stay in sync over Wi‑Fi':
      'Albei fone bly gesinchroniseer oor Wi-Fi',
  'Who is this for?': 'Vir wie is dit?',
  "Both are optional. The baby's name is shared with your partner's phone when you connect.": 'Albei is opsioneel. Die baba se naam word met jou maat se foon gedeel wanneer julle koppel.',
  "Baby's name": 'Baba se naam',
  'Baby’s name': 'Baba se naam',
  'This phone belongs to': 'Hierdie foon behoort aan',
  'e.g. Emma': 'bv. Emma',
  "e.g. Mom's phone": 'bv. Ma se foon',
  'e.g. Markus': 'bv. Markus',
  'Light or dark?': 'Lig of donker?',
  'Dark is easier on the eyes during night feeds.':
      'Donker is sagter op die oë tydens nagvoedings.',
  'Light': 'Lig',
  'Dark': 'Donker',
  'Match phone': 'Volg foon',
  'Appearance': 'Voorkoms',
  'Theme': 'Tema',
  'Share with your partner': 'Deel met jou maat',
  'Share with partner': 'Deel met maat',
  'Connect the other phone now, or skip and do it later in Settings.': 'Koppel die ander foon nou, of slaan oor en doen dit later in Instellings.',
  'Good morning': 'Goeiemôre',
  'Good afternoon': 'Goeiemiddag',
  'Good evening': 'Goeienaand',
  'Night shift': 'Nagskof',
  "{name}'s day": '{name} se dag',
  'Feed': 'Voeding',
  'Nappy': 'Doek',
  'Pill': 'Pil',
  'Log a feed': 'Teken voeding aan',
  'Pee or poo': 'Piepie of poef',
  'Left': 'Links',
  'Right': 'Regs',
  'Both': 'Albei',
  'Bottle': 'Bottel',
  'Pee': 'Piepie',
  'Poo': 'Poef',
  'Pee + Poo': 'Piepie + Poef',
  'Bottle feed': 'Bottelvoeding',
  'Feed · {side}': 'Voeding · {side}',
  'Nappy · {kind}': 'Doek · {kind}',
  'Next: {name}': 'Volgende: {name}',
  'Last feed': 'Laaste voeding',
  'Last nappy': 'Laaste doek',
  'No feeds yet': 'Nog geen voedings nie',
  'No nappies yet': 'Nog geen doeke nie',
  'Nothing yet': 'Nog niks nie',
  'just now': 'pas',
  '{time} ago': '{time} gelede',
  'in {time}': 'oor {time}',
  '{count} days': '{count} dae',
  '{count} min': '{count} min',
  'Feed reminder': 'Voedingsherinnering',
  'Pill reminders': 'Pilherinnerings',
  'Remind me': 'Herinner my',
  'Alarm': 'Wekker',
  'Notification': 'Kennisgewing',
  'Notification or alarm': 'Kennisgewing of wekker',
  'Notifications': 'Kennisgewings',
  'Reminders': 'Herinnerings',
  'Remind after': 'Herinner ná',
  'Which pills remind you, and when, is set per pill on the Pills tab.': 'Kies per pil op die Pille-oortjie watter herinnerings jy ontvang en wanneer.',
  'Not set': 'Nie ingestel nie',
  'Your data': 'Jou data',
  'This device': 'Hierdie toestel',
  'Device name': 'Toestelnaam',
  'App version': 'Toepassingweergawe',
  'Run first-time setup again': 'Herhaal eerste opstelling',
  'Your saved data could not be read':
      'Jou gestoorde data kon nie gelees word nie',
  'Export backup': 'Voer rugsteun uit',
  'Import backup': 'Voer rugsteun in',
  'Nothing new in that backup': 'Niks nuuts in daardie rugsteun nie',
  'Export and import': 'Uitvoer en invoer',
  'Export CSV': 'Voer CSV uit',
  'Search': 'Soek',
  'Search history': 'Soek geskiedenis',
  'All': 'Alles',
  'By day': 'Per dag',
  'By week': 'Per week',
  'By month': 'Per maand',
  'By type': 'Per soort',
  'This week': 'Hierdie week',
  'Last week': 'Verlede week',
  'Week of {date}': 'Week van {date}',
  'Pick date': 'Kies datum',
  'Edit feed': 'Wysig voeding',
  'Pick a side, then Save or start the timer':
      'Kies ’n kant en stoor of begin die tydhouer',
  'Duration': 'Tydsduur',
  'Amount': 'Hoeveelheid',
  'Start timer': 'Begin tydhouer',
  'Save feed': 'Stoor voeding',
  'Stop timer': 'Stop tydhouer',
  'Discard': 'Gooi weg',
  'Discard changes?': 'Gooi veranderinge weg?',
  'Your changes have not been saved.': 'Jou veranderinge is nie gestoor nie.',
  'Keep editing': 'Hou aan wysig',
  'Save & stop': 'Stoor en stop',
  'Save and stop': 'Stoor en stop',
  'Feed saved': 'Voeding gestoor',
  'Nappy change': 'Doekruil',
  'Edit nappy': 'Wysig doek',
  'Tap one to save': 'Tik een om te stoor',
  'Nappy saved: {kind}': 'Doek gestoor: {kind}',
  'Deleted': 'Verwyder',
  'Changed on the other phone': 'Op die ander foon verander',
  'This was changed on the other phone while you had it open. Save your version over it?': 'Dit is op die ander foon verander terwyl jy dit oop gehad het. Stoor jou weergawe daaroor?',
  'Save mine': 'Stoor myne',
  'Logged by {name}': 'Aangeteken deur {name}',
  'Possible duplicate': 'Moontlike duplikaat',
  'Add baby': 'Voeg baba by',
  'Add a baby': 'Voeg ’n baba by',
  'Rename baby': 'Hernoem baba',
  'Enter a name': 'Voer ’n naam in',
  'Save or stop the feed timer before switching babies.':
      'Stoor of stop die voedingstydhouer voordat jy babas wissel.',
  'A little rhythm for {name}': '’n Klein ritme vir {name}',
  'Plan bath time, bedtime and the little things you do together.':
      'Beplan badtyd, slaaptyd en die klein dingetjies wat julle saam doen.',
  'Add routine': 'Voeg roetine by',
  'Routine history': 'Roetinegeskiedenis',
  'Make bath time part of the day': 'Maak badtyd deel van die dag',
  'Choose a time and the days that suit your family. Each baby has their own routines.': 'Kies ’n tyd en die dae wat jou gesin pas. Elke baba het hul eie roetines.',
  'Set up bath time': 'Stel badtyd op',
  'Bath time': 'Badtyd',
  'Bedtime': 'Slaaptyd',
  'Tummy time': 'Maagtyd',
  'A new little routine': '’n Nuwe klein roetine',
  'Edit routine': 'Wysig roetine',
  'Edit {name}': 'Wysig {name}',
  'Routine name': 'Roetinenaam',
  'Give your routine a name': 'Gee jou roetine ’n naam',
  'Repeat on': 'Herhaal op',
  'Every day': 'Elke dag',
  'Mon': 'Ma',
  'Tue': 'Di',
  'Wed': 'Wo',
  'Thu': 'Do',
  'Fri': 'Vr',
  'Sat': 'Sa',
  'Sun': 'So',
  'Choose at least one day': 'Kies minstens een dag',
  'Notes (optional)': 'Notas (opsioneel)',
  'Anything that helps your routine': 'Enigiets wat met jou roetine help',
  'Remind me on this device': 'Herinner my op hierdie toestel',
  'At the scheduled time on your chosen days':
      'Op die vasgestelde tyd op jou gekose dae',
  'Save routine': 'Stoor roetine',
  'Delete routine': 'Verwyder roetine',
  'Routine deleted': 'Roetine verwyder',
  'Routine active': 'Roetine aktief',
  'Routine paused': 'Roetine onderbreek',
  'Reminders on this device': 'Herinnerings aan op hierdie toestel',
  'Reminders off on this device': 'Herinnerings af op hierdie toestel',
  'Plan your baby’s routines': 'Beplan jou baba se roetines',
  'Set up bath time, bedtime and more': 'Stel badtyd, slaaptyd en meer op',
  'Mark done': 'Merk as gedoen',
  'Not done yet': 'Nog nie gedoen nie',
  'Last done: {details}': 'Laas gedoen: {details}',
  'Last {name}': 'Laaste {name}',
  'Mark {name} as done': 'Merk {name} as gedoen',
  'Who did it?': 'Wie het dit gedoen?',
  'e.g. Mum, Dad or a name': 'bv. Ma, Pa of ’n naam',
  'Enter who did the routine': 'Voer in wie die roetine gedoen het',
  'Save completion': 'Stoor voltooiing',
  'Choose a time that has already happened': 'Kies ’n tyd wat reeds verby is',
  'This routine was removed. Close and refresh the routines list.':
      'Hierdie roetine is verwyder. Maak toe en verfris die roetinelys.',
  '{name} marked done': '{name} as gedoen gemerk',
  'No completions yet': 'Nog geen voltooiings nie',
  '{name} history': '{name} se geskiedenis',
  'Remove completion': 'Verwyder voltooiing',
  'Completion removed': 'Voltooiing verwyder',
  'View routines': 'Bekyk roetines',
  'Add pill': 'Voeg pil by',
  'Edit pill': 'Wysig pil',
  'Name': 'Naam',
  'Dose': 'Dosis',
  'Schedule': 'Skedule',
  'First dose': 'Eerste dosis',
  'Times a day': 'Keer per dag',
  'Every few hours': 'Elke paar uur',
  'Taken': 'Geneem',
  'Take now': 'Neem nou',
  'Log dose': 'Teken dosis aan',
  'Due now': 'Nou verskuldig',
  'Next {time}': 'Volgende {time}',
  '{count}× a day': '{count}× per dag',
  'Every {count} hours': 'Elke {count} uur',
  'Every {count} hour': 'Elke {count} uur',
  'No pills yet': 'Nog geen pille nie',
  'Pair partner': 'Koppel maat',
  'Paired': 'Gekoppel',
  'Synced': 'Gesinchroniseer',
  'Syncing': 'Besig om te sinchroniseer',
  'Sync paused': 'Sinchronisasie onderbreek',
  'Not synced': 'Nie gesinchroniseer nie',
  'Sync now': 'Sinchroniseer nou',
  'Sync automatically': 'Sinchroniseer outomaties',
  'No partner device yet': 'Nog geen maat se toestel nie',
  'Connect once, then it syncs by itself.':
      'Koppel een keer, dan sinchroniseer dit self.',
  'After every change and every minute': 'Ná elke verandering en elke minuut',
  'Keep syncing when closed': 'Hou aan sinchroniseer wanneer gesluit',
  'Shows a quiet notification while on':
      'Wys ’n stil kennisgewing terwyl dit aan is',
  'Allow background use': 'Laat agtergrondgebruik toe',
  'Otherwise Android may pause syncing while the screen is off':
      'Anders kan Android sinchronisasie onderbreek wanneer die skerm af is',
  'ADDRESS': 'ADRES',
  'CODE': 'KODE',
  'Address': 'Adres',
  'Code': 'Kode',
  'Scan code': 'Skandeer kode',
  'Type code': 'Tik kode in',
  'Connect': 'Koppel',
  'Connect to the other phone': 'Koppel aan die ander foon',
  'Both phones keep the same log over your home Wi‑Fi. On the other phone, open Settings and scan this code.': 'Albei fone hou dieselfde logboek oor jou huis se Wi-Fi. Maak Instellings op die ander foon oop en skandeer hierdie kode.',
  'Type the address and code shown in Settings on the other phone.': 'Tik die adres en kode in wat onder Instellings op die ander foon gewys word.',
  'Sync could not start on this device.':
      'Sinchronisasie kon nie op hierdie toestel begin nie.',
  'Connect to Wi‑Fi to pair.': 'Koppel aan Wi-Fi om toestelle te koppel.',
  'Not on the same Wi-Fi? Sync by QR code':
      'Nie op dieselfde Wi-Fi nie? Sinchroniseer met ’n QR-kode',
  'Connected and synced': 'Gekoppel en gesinchroniseer',
  'Up to date': 'Op datum',
  'This phone': 'Hierdie foon',
  'What is shared': 'Wat gedeel word',
  'Babies': 'Babas',
  'Routines done': 'Roetines gedoen',
  'Pill doses': 'Pildosisse',
  'Different app versions': 'Verskillende toepassingweergawes',
  'Continue anyway': 'Gaan tog voort',
  'Not now': 'Nie nou nie',
  'Not known yet': 'Nog nie bekend nie',
  'Older version': 'Ouer weergawe',
  'Send everything again': 'Stuur alles weer',
  'Time for a feed': 'Tyd vir ’n voeding',
  'Reminder you set after the last feed':
      'Herinnering wat jy ná die laaste voeding ingestel het',
  '{name}: time for a feed': '{name}: tyd vir ’n voeding',
  'Pill time: {name}': 'Piltyd: {name}',
  'Time to take your {name}': 'Tyd om jou {name} te neem',
  'Take {dose}': 'Neem {dose}',
  'Time for {name}': 'Tyd vir {name}',
  'Log feed': 'Teken voeding aan',
  'Stop': 'Stop',
  'Snooze {count} min': 'Sluimer {count} min',
  'Now': 'Nou',
  'Just now': 'Pas',
  'Other time': 'Ander tyd',
  'Not yet': 'Nog nie',
  'No feeds logged': 'Nog geen voedings aangeteken nie',
  'No nappies logged': 'Nog geen doeke aangeteken nie',
  'Nothing logged yet': 'Nog niks aangeteken nie',
  'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.': 'Nog niks vandag aangeteken nie.\nTik Voeding, Doek of Pil hier bo om te begin.',
  'SINCE LAST FEED': 'SEDERT LAASTE VOEDING',
  'SINCE LAST NAPPY': 'SEDERT LAASTE DOEK',
  'TODAY': 'VANDAG',
  'See all history': 'Bekyk volledige geskiedenis',
  'Stop & save': 'Stop en stoor',
  'How long (optional)': 'Hoe lank (opsioneel)',
  'Amount (optional)': 'Hoeveelheid (opsioneel)',
  'How many (optional)': 'Hoeveel (opsioneel)',
  'Breast': 'Bors',
  'Take a pill': 'Neem ’n pil',
  'Taken now': 'Nou geneem',
  'Add a pill': 'Voeg ’n pil by',
  'Add another pill': 'Voeg nog ’n pil by',
  'Add pills': 'Voeg pille by',
  'Save pill': 'Stoor pil',
  'First dose at': 'Eerste dosis om',
  'How often': 'Hoe gereeld',
  'Every X hours': 'Elke X uur',
  'DOSE TIMES': 'DOSISTYE',
  'REMINDER BY DOSE TIME': 'HERINNERING PER DOSISTYD',
  'Remind me on this phone': 'Herinner my op hierdie foon',
  'Reminders are set per dose time on this phone. The other phone has its own settings.': 'Herinnerings word per dosistyd op hierdie foon ingestel. Die ander foon het sy eie instellings.',
  'Edit when it was taken': 'Wysig wanneer dit geneem is',
  'Mark as taken now': 'Merk as nou geneem',
  'e.g. 1 tablet': 'bv. 1 tablet',
  'e.g. Iron, Vitamins': 'bv. Yster, Vitamiene',
  'Every {count} hours does not fit a day evenly, so the times restart each day at the first dose.': 'Elke {count} uur pas nie eweredig in ’n dag nie; die tye begin dus elke dag weer by die eerste dosis.',
  'The dose times and alarms are worked out for you.':
      'Die dosistye en wekkers word vir jou uitgewerk.',
  'Get an alarm when the next feed is due, and when it is time for your pills.': 'Kry ’n wekker wanneer die volgende voeding verwag word en wanneer dit tyd vir jou pille is.',
  'Feed reminder is off. Tap to set one':
      'Voedingsherinnering is af. Tik om een in te stel',
  'Next feed reminder at {time}': 'Volgende voedingsherinnering om {time}',
  'Group by': 'Groepeer volgens',
  'Day': 'Dag',
  'Week': 'Week',
  'Month': 'Maand',
  'Type': 'Soort',
  'Search, e.g. poo, left, iron, monday':
      'Soek, bv. poef, links, yster, maandag',
  'A spreadsheet export is on the History tab.':
      'Voer ’n sigblad uit op die Geskiedenis-oortjie.',
  'Export as spreadsheet': 'Voer as sigblad uit',
  'Adds to what is here': 'Voeg by wat reeds hier is',
  'Duration (min)': 'Tydsduur (min)',
  'Amount (ml)': 'Hoeveelheid (ml)',
  'What': 'Wat',
  'Choose a Baby Log backup': 'Kies ’n Baby Log-rugsteun',
  'Saved {file}': '{file} gestoor',
  'Save {file}': 'Stoor {file}',
  'Could not import: {error}': 'Kon nie invoer nie: {error}',
  'Could not save: {error}': 'Kon nie stoor nie: {error}',
  'Could not sync: {error}': 'Kon nie sinchroniseer nie: {error}',
  'Could not connect: {error}': 'Kon nie koppel nie: {error}',
  'Could not read the codes: {error}': 'Kon nie die kodes lees nie: {error}',
  'Sync by QR code': 'Sinchroniseer met QR-kode',
  'Show my code': 'Wys my kode',
  'Scan theirs': 'Skandeer hul kode',
  'Point the camera at the code on the other phone':
      'Rig die kamera op die kode op die ander foon',
  'Now show your code so the other phone gets your changes too.':
      'Wys nou jou kode sodat die ander foon ook jou veranderinge kry.',
  'That is a pairing code. On the other phone choose Sync by QR code.':
      'Dit is ’n koppelkode. Kies Sinchroniseer met QR-kode op die ander foon.',
  'Up to date. Pair the other phone in Settings to sync.':
      'Op datum. Koppel die ander foon in Instellings om te sinchroniseer.',
  'Synced with {name}': 'Met {name} gesinchroniseer',
  'Synced {time} · tap for details':
      '{time} gesinchroniseer · tik vir besonderhede',
  'Not synced: different app versions':
      'Nie gesinchroniseer nie: verskillende toepassingweergawes',
  'This device is no longer paired': 'Hierdie toestel is nie meer gekoppel nie',
  'all changes since you last synced':
      'alle veranderinge sedert jou laaste sinchronisasie',
  'baby profile': 'babaprofiel',
  'baby profiles': 'babaprofiele',
  'pill dose': 'pildosis',
  'pill doses': 'pildosisse',
  'routine completion': 'roetinevoltooiing',
  'routine completions': 'roetinevoltooiings',
  'this phone': 'hierdie foon',
  'Remind me to feed': 'Herinner my om te voed',
  'Counted from the start of the last feed':
      'Gemeet vanaf die begin van die laaste voeding',
  'How long after a feed?': 'Hoe lank ná ’n voeding?',
  'How they ring on this phone': 'Hoe hulle op hierdie foon lui',
  'A normal notification with your notification sound.':
      '’n Gewone kennisgewing met jou kennisgewingklank.',
  'Rings with your alarm sound until you stop or snooze it, even on silent, and shows on the lock screen.': 'Lui met jou wekkerklank totdat jy dit stop of laat sluimer, selfs op stil, en verskyn op die sluitskerm.',
  'Add a pill, say how often you take it and when you start.':
      'Voeg ’n pil by en kies hoe gereeld jy dit neem en wanneer jy begin.',
  'Importing adds to your log and never deletes anything.':
      'Invoer voeg by jou logboek en verwyder nooit iets nie.',
  'For when the phones are not on the same Wi-Fi. One phone shows its code and the other scans it, then swap so both have everything.': 'Vir wanneer die fone nie op dieselfde Wi-Fi is nie. Een foon wys sy kode en die ander skandeer dit. Ruil dan om sodat albei alles het.',
  'Different versions may store things differently, so some entries could sync wrongly. Best is to install the same version on both phones.': 'Verskillende weergawes kan data anders stoor, wat sinchronisasiefoute kan veroorsaak. Installeer verkieslik dieselfde weergawe op albei fone.',
  'This phone has version {version}, {name} has {other}.':
      'Hierdie foon het weergawe {version}; {name} het {other}.',
  'Feeds, nappies, pill doses, pills and deletions are shared. Settings, reminders, the theme and device names stay on each phone. The counts match once both phones are in sync.': 'Voedings, doeke, pildosisse, pille en verwyderings word gedeel. Instellings, herinnerings, die tema en toestelname bly op elke foon. Die getalle stem ooreen wanneer albei fone gesinchroniseer is.',
  'Use default (alarm)': 'Gebruik verstek (wekker)',
  'Use default (notification)': 'Gebruik verstek (kennisgewing)',
  'Scan partner\'s code': 'Skandeer jou maat se kode',
  'A copy was kept. Use Import backup and choose:\n{path}':
      '’n Kopie is behou. Kies Voer rugsteun in en kies:\n{path}',
  'Imported {entries} entries, {pills} pills, {profiles} profiles, {routines} routines and {completions} completions': '{entries} inskrywings, {pills} pille, {profiles} profiele, {routines} roetines en {completions} voltooiings ingevoer',
  '{body} (snoozed)': '{body} (sluimer)',
};
