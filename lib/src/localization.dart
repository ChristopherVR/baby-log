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
    super.suffixText,
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
    super.keyboardType,
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
  "Growth": "Groei",
  "Growth journal": "Groeijoernaal",
  "Edit profile": "Wysig profiel",
  "Baby’s profile": "Baba se profiel",
  "A little introduction to your favourite person.":
      "’n Klein bekendstelling aan jou gunstelingmens.",
  "Choose profile photo": "Kies profielfoto",
  "Choose a photo": "Kies ’n foto",
  "Remove photo": "Verwyder foto",
  "Baby photo": "Babafoto",
  "Opening photo…": "Maak foto oop…",
  "Date of birth": "Geboortedatum",
  "Add a birthday to see age and monthly milestones":
      "Voeg ’n geboortedatum by om ouderdom en maandelikse mylpale te sien",
  "Remove date of birth": "Verwyder geboortedatum",
  "Save profile": "Stoor profiel",
  "The birthday must be on or before the first growth entry.":
      "Die geboortedatum moet op of voor die eerste groei-inskrywing wees.",
  "Choose a JPG, PNG or WebP photo under 20 MB.":
      "Kies ’n JPG-, PNG- of WebP-foto kleiner as 20 MB.",
  "Every little moment matters": "Elke klein oomblik maak saak",
  "{days} days old": "{days} dae oud",
  "{months} months old": "{months} maande oud",
  "{months} months": "{months} maande",
  "GROWING TOGETHER": "GROEI SAAM",
  "Little by little.": "Bietjie vir bietjie.",
  "Their story, one month at a time.": "Hul storie, een maand op ’n slag.",
  "Add a moment": "Voeg ’n oomblik by",
  "This month is in your journal. You can add more anytime.":
      "Hierdie maand is in jou joernaal. Voeg gerus nog by.",
  "A photo and a measurement each month make a lovely keepsake.":
      "’n Foto en ’n meting elke maand maak ’n pragtige aandenking.",
  "Look how you’ve grown": "Kyk hoe het jy gegroei",
  "Then": "Toe",
  "Growing at your own pace": "Groei teen jou eie pas",
  "Your recorded measurements over time.": "Jou aangetekende metings oor tyd.",
  "The little moments": "Die klein oomblikke",
  "A story only you can tell": "’n Storie wat net jy kan vertel",
  "Add your first photo, weight or height. Come back each month to see all those little changes.": "Voeg jou eerste foto, gewig of lengte by. Kom elke maand terug om al die klein veranderinge te sien.",
  "A little moment": "’n Klein oomblik",
  "Edit moment": "Wysig oomblik",
  "A photo, a measurement, a memory. Add any or all.":
      "’n Foto, ’n meting, ’n herinnering. Voeg enige of almal by.",
  "Add a photo": "Voeg ’n foto by",
  "Change photo": "Verander foto",
  "Weight": "Gewig",
  "Height": "Lengte",
  "A memory (optional)": "’n Herinnering (opsioneel)",
  "That first little smile…": "Daardie eerste glimlaggie…",
  "Save moment": "Stoor oomblik",
  "Enter a number greater than zero": "Voer ’n getal groter as nul in",
  "Add a photo, measurement or memory with a date on or after birth.":
      "Voeg ’n foto, meting of herinnering by met ’n datum op of na geboorte.",
  "Delete this moment?": "Verwyder hierdie oomblik?",
  "This removes its photo and measurements from the journal.":
      "Dit verwyder die foto en metings uit die joernaal.",
  "Delete moment": "Verwyder oomblik",
  "Moment deleted": "Oomblik verwyder",
  "since first entry": "sedert eerste inskrywing",
  "Add another measurement to see the changes.":
      "Voeg nog ’n meting by om die veranderinge te sien.",
  "A little burping break": "’n Kort windjiebreek",
  "Timer paused · take your time": "Tydhouer onderbreek · neem jou tyd",
  "Active feeding time": "Aktiewe voedingstyd",
  "Resume feeding": "Hervat voeding",
  "Pause to burp": "Pouse vir ’n windjie",
  "Every 5 minutes": "Elke 5 minute",
  "Remind me during active feeding": "Herinner my tydens aktiewe voeding",
  "Discard this feed?": "Verwerp hierdie voeding?",
  "The timer will stop without saving a feed.":
      "Die tydhouer sal stop sonder om ’n voeding te stoor.",
  "Keep feeding": "Hou aan voed",
  "Feeding check-in": "Voedingsherinnering",
  "Another 5 minutes of feeding. Open Nestling to pause or finish.": "Nog 5 minute se voeding. Maak Nestling oop om te onderbreek of klaar te maak.",
  "Feeding reminders are unavailable. Check notification permissions.": "Voedingsherinnerings is nie beskikbaar nie. Gaan kennisgewingtoestemmings na.",
  "Growth entries": "Groei-inskrywings",
  "growth entry": "groei-inskrywing",
  "growth entries": "groei-inskrywings",
  "Imported {entries} entries, {meds} pills, {babies} profiles and {routines} routines and {completions} completions, {growth} growth entries": "{entries} inskrywings, {meds} pille, {babies} profiele, {routines} roetines, {completions} voltooiings en {growth} groei-inskrywings ingevoer",
  'What’s new': 'Wat is nuut',
  'Version {version}': 'Weergawe {version}',
  'Got it': 'Goed so',
  'Nighttime': 'Nagtyd',
  'Night light · softer colours until 6 am':
      'Nagliggie · sagter kleure tot 06:00',
  'Night light': 'Nagliggie',
  'Turn off': 'Skakel af',
  'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.':
      "Demp die kleure van 18:00 tot 06:00 sodat die skerm sag is in 'n donker kamer.",
  "Use this device's own name": 'Gebruik die toestel se eie naam',
  'Not paired yet': 'Nog nie gekoppel nie',
  'A name you chose': "'n Naam wat jy gekies het",
  'Set by this device': 'Deur hierdie toestel gestel',
  'Type a name your partner will recognise':
      'Tik ’n naam wat jou maat sal herken',
  'It is a softer light theme, not dark mode. Choose Dark above for dark all day.':
      "Dit is 'n sagter ligte tema, nie donker modus nie. Kies Donker hierbo vir heeldag donker.",
  'App updates are available on Android.':
      'Appopdaterings is op Android beskikbaar.',
  'App updates': 'Appopdaterings',
  'Refresh': 'Verfris',
  'Refreshing': 'Besig om te verfris',
  'Updates for this version are provided by Google Play.':
      'Opdaterings vir hierdie weergawe word deur Google Play verskaf.',
  'Open Google Play': 'Maak Google Play oop',
  'Could not open Google Play. Open the Play Store to update Nestling.': 'Kon nie Google Play oopmaak nie. Maak die Play Winkel oop om Nestling op te dateer.',
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
  'Allow updates from Nestling, then return and tap Update again.': 'Laat opdaterings van Nestling toe, keer dan terug en tik weer Dateer op.',
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
  'Nestling': 'Nestling',
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
  'Start using Nestling': 'Begin Nestling gebruik',
  'Welcome to Nestling': 'Welkom by Nestling',
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
  'Family hub': 'Gesinsgroep',
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
  'Sleep': 'Slaap',
  'Sleeping': 'Slaap tans',
  'Put down for a nap': 'Lê neer vir ’n slapie',
  'Start nap': 'Begin slapie',
  'End nap': 'Beëindig slapie',
  'Nap started': 'Slapie begin',
  'Nap ended': 'Slapie geëindig',
  'Edit sleep': 'Wysig slaap',
  'Has the nap finished?': 'Is die slapie klaar?',
  'End the nap now, or keep tracking sleep.':
      'Beëindig die slapie nou, of hou aan slaap aanteken.',
  'Still sleeping': 'Slaap nog',
  'Choose valid start and end times in the past':
      'Kies geldige begin- en eindtye in die verlede',
  'A nap is already being tracked': '’n Slapie word reeds aangeteken',
  'Log': 'Logboek',
  'Charts': 'Grafieke',
  'Activity log': 'Aktiwiteitslogboek',
  'Everything logged for this baby, newest first. Time filters use entry start times.': 'Alles wat vir hierdie baba aangeteken is, nuutste eerste. Tydfilters gebruik die begintye van inskrywings.',
  'All time': 'Alle tye',
  'Choose day': 'Kies dag',
  'Date range': 'Datumreeks',
  'Previous day': 'Vorige dag',
  'Next day': 'Volgende dag',
  'Time of day': 'Tyd van die dag',
  'All hours': 'Alle ure',
  'No entries match these filters':
      'Geen inskrywings pas by hierdie filters nie',
  'Totals and patterns for this baby in the selected period.':
      'Totale en patrone vir hierdie baba in die gekose tydperk.',
  'By hour': 'Per uur',
  'Each bar totals that hour across the selected dates. Tap a bar for details; swipe to see more.': 'Elke staaf tel daardie uur oor die gekose datums. Tik ’n staaf vir besonderhede; vee om meer te sien.',
  'Each bar is one calendar day. Tap a bar for details; swipe to see more.': 'Elke staaf is een kalenderdag. Tik ’n staaf vir besonderhede; vee om meer te sien.',
  'Mixed nappies count as both wee and poo. Empty days count as zero; today is incomplete.': 'Gemengde doeke tel as beide piepie en poef. Leë dae tel as nul; vandag is onvolledig.',
  'Feeds per day': 'Voedings per dag',
  'Sleep hours by hour': 'Slaapure per uur',
  'Feed minutes per day': 'Voedingsminute per dag',
  'Bottle ml per day': 'Bottel-ml per dag',
  'Pills per day': 'Pille per dag',
  'Average per day': 'Gemiddeld per dag',
  'Total': 'Totaal',
  'Wees': 'Piepie',
  'Poos': 'Poef',
  'Peak hour': 'Spitsuur',
  'Sleep is split across the hours and days it covers. Ongoing sleep is included up to now. Feed duration and bottle volume include recorded values only.': 'Slaap word oor die betrokke ure en dae verdeel. Huidige slaap word tot nou ingesluit. Voedingsduur en bottelvolume sluit slegs aangetekende waardes in.',
  'Next-day estimate': 'Skatting vir die volgende dag',
  'Average of {days} completed days in this range, including days with no logs. Today is excluded.': 'Gemiddeld van {days} voltooide dae in hierdie reeks, insluitend dae sonder inskrywings. Vandag word uitgesluit.',
  'Estimates describe recorded patterns. Missing logs affect the result.': 'Skattings beskryf aangetekende patrone. Ontbrekende inskrywings beïnvloed die resultaat.',
  'Select a range with logs on at least 3 completed days to see an estimate. Today is excluded.': 'Kies ’n reeks met inskrywings op minstens 3 voltooide dae om ’n skatting te sien. Vandag word uitgesluit.',
  'Discover daily patterns': 'Ontdek daaglikse patrone',
  'Charts use all logs for this baby in the selected period. Mixed nappies count as both wee and poo.': 'Grafieke gebruik alle inskrywings vir hierdie baba in die gekose tydperk. Gemengde doeke tel as beide piepie en poef.',
  '{days} days': '{days} dae',
  'Daily totals': 'Daaglikse totale',
  'Wees per day': 'Piepie per dag',
  'Poos per day': 'Poef per dag',
  'Sleep hours per day': 'Slaapure per dag',
  'Sleep is split at midnight. An ongoing nap is included up to now.': 'Slaap word om middernag verdeel. ’n Huidige slapie word tot nou ingesluit.',
  'Patterns by hour': 'Patrone per uur',
  'Total logs in each hour across the selected days. Tap a bar for its exact count; swipe to see all hours.': 'Totale inskrywings per uur oor die gekose dae. Tik ’n staaf vir die presiese getal; vee om alle ure te sien.',
  'Feeds by hour': 'Voedings per uur',
  'Poos by hour': 'Poef per uur',
  'Wees by hour': 'Piepie per uur',
  'No logs in this period': 'Geen inskrywings in hierdie tydperk nie',
  'Most logged': 'Meeste aangeteken',
  'Highest day': 'Hoogste dag',
  'Scale': 'Skaal',
  'Since {time}': 'Sedert {time}',
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
  'Share': 'Deel',
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
  'Add a device': 'Voeg ’n toestel by',
  'Both phones keep the same log over your home Wi‑Fi. On the other phone, open Settings and scan this code.': 'Albei fone hou dieselfde logboek oor jou huis se Wi-Fi. Maak Instellings op die ander foon oop en skandeer hierdie kode.',
  'Type the address and code shown on the other device (Settings, Family hub).': 'Tik die adres en kode in wat op die ander toestel gewys word (Instellings, Gesinsgroep).',
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
  'Get a reminder when the next feed is due, and when it is time for your pills.':
      'Kry ’n herinnering wanneer die volgende voeding verwag word en wanneer dit tyd vir jou pille is.',
  'Pill reminders show as normal notifications.':
      'Pilherinneringe verskyn as gewone kennisgewings.',
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
  'Choose a Nestling backup': 'Kies ’n Nestling-rugsteun',
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
  'Synced {time}': '{time} gesinchroniseer',
  'Synced {time} · tap for details':
      '{time} gesinchroniseer · tik vir besonderhede',
  'Not synced: different app versions':
      'Nie gesinchroniseer nie: verskillende toepassingweergawes',
  'This device is no longer in the hub': 'Hierdie toestel is nie meer in die groep nie',
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
  'Scan the other device\'s code': 'Skandeer die ander toestel se kode',
  'A copy was kept. Use Import backup and choose:\n{path}':
      '’n Kopie is behou. Kies Voer rugsteun in en kies:\n{path}',
  'Imported {entries} entries, {pills} pills, {profiles} profiles, {routines} routines and {completions} completions': '{entries} inskrywings, {pills} pille, {profiles} profiele, {routines} roetines en {completions} voltooiings ingevoer',
  '{body} (snoozed)': '{body} (sluimer)',
  "Optional. The baby's name is shared with your partner's phone when you connect.":
      'Opsioneel. Die baba se naam word met jou maat se foon gedeel wanneer julle koppel.',
  'You are all set!': 'Alles is reg!',
  'Change anything later in Settings.': 'Verander enigiets later in Instellings.',
  'More options': 'Meer opsies',
  'Show everything': 'Wys alles',
  'Try another day, or show everything.': 'Probeer ’n ander dag, of wys alles.',
  'Feeds, nappies, sleep and pills you log on the Today screen will show up here.': 'Voedings, doeke, slaap en pille wat jy op die Vandag-skerm aanteken, verskyn hier.',
  'What happened and when, newest first.': 'Wat het gebeur en wanneer, nuutste eerste.',
  'Everything that was logged, newest first': 'Alles wat aangeteken is, nuutste eerste',
  'Patterns over time: feeds, nappies, sleep': 'Patrone oor tyd: voedings, doeke, slaap',
  'Save a weight, height, photo or memory. Any one is enough.': 'Stoor ’n gewig, lengte, foto of herinnering. Enige een is genoeg.',
  'Latest measurements': 'Jongste metings',
  'Growth over time': 'Groei oor tyd',
  'Journal': 'Joernaal',
  'Newest first. Tap an entry to edit it.': 'Nuutste eerste. Tik op ’n inskrywing om dit te wysig.',
  'Track how your baby grows': 'Hou dop hoe jou baba groei',
  'Add a weight, height or photo now and then, for example at each clinic visit. You will see the latest numbers, a chart and a keepsake journal here.': 'Voeg af en toe ’n gewig, lengte of foto by, byvoorbeeld by elke kliniekbesoek. Jy sal hier die jongste syfers, ’n grafiek en ’n aandenkingsjoernaal sien.',
  'Not measured yet': 'Nog nie gemeet nie',
  'since': 'sedert',
  'Pick the date, then add a measurement, a photo or a memory. Any one is enough.': 'Kies die datum, voeg dan ’n meting, foto of herinnering by. Enige een is genoeg.',
  'Devices sharing this log': 'Toestelle wat hierdie logboek deel',
  'Everyone in the hub sees the same log. Add a device once, it then shares with everyone else automatically.': 'Almal in die groep sien dieselfde logboek. Voeg ’n toestel net een keer by, dan deel dit outomaties met almal.',
  'Everyone in the hub keeps the same log over your home Wi‑Fi. On the device you are adding, open Settings and scan this code. Add a device once and it shares with everyone else automatically.': 'Almal in die groep hou dieselfde logboek oor jou huis se Wi-Fi. Maak Instellings oop op die toestel wat jy byvoeg en skandeer hierdie kode. Voeg ’n toestel net een keer by, dan deel dit outomaties met almal.',
  'Sync details': 'Sinchronisasie-besonderhede',
  'This device · version {version}': 'Hierdie toestel · weergawe {version}',
  'No other devices yet': 'Nog geen ander toestelle nie',
  'Add a device to share this log.': 'Voeg ’n toestel by om hierdie logboek te deel.',
  'Paused: different app version': 'Onderbreek: ander toepassingweergawe',
  'Not reachable right now': 'Nie nou bereikbaar nie',
  'Waiting to connect': 'Wag om te koppel',
  'Not synced yet': 'Nog nie gesinchroniseer nie',
  'Another device': '’n Ander toestel',
  'Recent sync activity': 'Onlangse sinchronisasie-aktiwiteit',
  '{count} came in': '{count} ingekom',
  '{count} sent': '{count} gestuur',
  'Last sync {time}': 'Laaste sinchronisasie {time}',
  'Remove from hub': 'Verwyder uit die groep',
  'Device added and synced': 'Toestel bygevoeg en gesinchroniseer',
  "Optional. Names are shared with your partner's phone when you connect. ": 'Opsioneel. Name word met jou lewensmaat se foon gedeel wanneer julle koppel. ',
  "Add every baby you want to keep track of.": 'Voeg elke baba by wat jy wil dophou.',
  'Another baby': 'Nog ’n baba',
  'e.g. Noah': 'bv. Noah',
  'Add another baby': 'Voeg nog ’n baba by',
  'Remove': 'Verwyder',
  'Selected': 'Gekies',
  'Select': 'Kies',
  'Tap a baby to change their name, birthday or photo. The selected baby is the one you see on the other tabs.': 'Tik op ’n baba om die naam, verjaardag of foto te verander. Die gekose baba is die een wat jy op die ander oortjies sien.',
  'For {name}': 'Vir {name}',
  'For you, on this phone': 'Vir jou, op hierdie foon',
  'The feed reminder is kept for each baby: it follows the selected baby. Which pills remind you, and when, is set per pill on the Pills tab.': 'Die voedingsherinnering word vir elke baba gehou: dit volg die gekose baba. Watter pille jou herinner, en wanneer, word per pil op die Pille-oortjie gestel.',
  'Quick actions': 'Vinnige aksies',
  'Go to': 'Gaan na',
  'Start feed timer': 'Begin voedingstydhouer',
  'Log a nappy': 'Teken ’n doek aan',
  'Start a nap': 'Begin ’n slapie',
  'Add a growth entry': 'Voeg ’n groei-inskrywing by',
  'Photo': 'Foto',
  'Search feeds, pills, routines, settings…': 'Soek voedings, pille, roetines, instellings…',
  'No results for “{query}”': 'Geen resultate vir “{query}” nie',
  'Try another word, a date or a name.': 'Probeer ’n ander woord, ’n datum of ’n naam.',
  'Recent': 'Onlangs',
  '{shown} of {total}': '{shown} van {total}',
  'Navigate': 'Beweeg',
  'Open': 'Maak oop',
  'Switch baby': 'Wissel baba',
  '{count} babies': '{count} babas',
  'Search…': 'Soek…',
  'SLEEP': 'SLAAP',
  'SLEEPING': 'SLAAP NOU',
  'Awake': 'Wakker',
  'NEXT PILL': 'VOLGENDE PIL',
  'None': 'Geen',
  'Plan': 'Beplan',
  'Timer': 'Tydhouer',
  'Nap': 'Slapie',
  'Routine': 'Roetine',
  'Reminder': 'Herinnering',
  'Birthday': 'Verjaardag',
  'Sync': 'Sinchroniseer',
  'Pair': 'Koppel',
  'Device': 'Toestel',
  'by {name}': 'deur {name}',
};
