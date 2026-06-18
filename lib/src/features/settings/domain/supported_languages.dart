/// Languages ALTER supports for profile, voice locale, and onboarding.
const kSupportedLanguageNames = [
  'English',
  'Hindi',
  'Kannada',
  'Tamil',
  'Telugu',
  'Malayalam',
  'Marathi',
  'Bengali',
  'Gujarati',
  'Punjabi',
  'Urdu',
];

/// Maps profile language name to BCP-47 locale for STT/TTS.
String localeForLanguageName(String name) {
  return switch (name.toLowerCase()) {
    'hindi' => 'hi-IN',
    'kannada' => 'kn-IN',
    'tamil' => 'ta-IN',
    'telugu' => 'te-IN',
    'malayalam' => 'ml-IN',
    'marathi' => 'mr-IN',
    'bengali' => 'bn-IN',
    'gujarati' => 'gu-IN',
    'punjabi' => 'pa-IN',
    'urdu' => 'ur-IN',
    _ => 'en-IN',
  };
}
