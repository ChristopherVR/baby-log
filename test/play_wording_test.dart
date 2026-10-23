import 'package:baby_app/src/distribution.dart';
import 'package:baby_app/src/localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = Distribution.play;
  tearDown(() => Distribution.play = original);

  test('the Play build says habits instead of pills', () {
    Distribution.play = true;
    expect(tr('Pills', language: 'en'), 'Habits');
    expect(tr('Pills', language: 'af'), 'Gewoontes');
    expect(tr('Pill time: Pumping', language: 'en'), 'Habit time: Pumping');
    expect(tr('08:00 · taken 09:05', language: 'en'), '08:00 · done 09:05');
    expect(
      tr(
        'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.',
        language: 'af',
      ),
      'Nog niks vandag aangeteken nie.\n'
      'Tik Voeding, Doek of Gewoonte hier bo om te begin.',
    );
  });

  test('other builds keep the pill wording', () {
    Distribution.play = false;
    expect(tr('Pills', language: 'en'), 'Pills');
    expect(tr('Pills', language: 'af'), 'Pille');
  });

  test('every Play wording has an Afrikaans translation', () {
    expect(
      playWording.values.where((text) => !afrikaans.containsKey(text)),
      isEmpty,
    );
  });
}
