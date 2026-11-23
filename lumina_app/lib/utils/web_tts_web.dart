import 'dart:html' as html;

Future<void> speak(String text) async {
  try {
    final utter = html.SpeechSynthesisUtterance(text);
    // Optionally set voice parameters
    utter.lang = 'en-US';
    utter.rate = 0.95;
    html.window.speechSynthesis?.speak(utter);
  } catch (e) {
    // ignore
  }
}
