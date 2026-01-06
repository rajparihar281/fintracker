class UpiQrParser {
  static Map<String, String> parse(String rawValue) {
    try {
      final uri = Uri.parse(rawValue);
      if (uri.scheme != 'upi') return {};
      return uri.queryParameters;
    } catch (e) {
      return {};
    }
  }
}
