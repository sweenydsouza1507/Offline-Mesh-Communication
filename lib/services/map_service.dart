import 'package:url_launcher/url_launcher.dart';

class MapService {
  static Future<void> openInMaps(double lat, double lng, {String? label}) async {
    final encodedLabel = Uri.encodeComponent(label ?? 'Friend Location');

    final uris = [
      // OsmAnd (best offline maps)
      Uri.parse('osmand.geo:$lat,$lng?q=$encodedLabel'),
      // Standard geo intent
      Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)'),
      // Maps.me fallback
      Uri.parse('mapswithme://map?ll=$lat,$lng&n=$encodedLabel'),
    ];

    for (final uri in uris) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }

    // No maps app found — caller should navigate to in-app MapScreen
    throw Exception('No offline maps app found. Please install OsmAnd.');
  }
}