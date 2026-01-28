/// Supported DRM schemes for the native players.
enum RhsDrmType { none, widevine, clearKey }

/// Bundle of DRM configuration passed to the native player engines.
///
/// The same config object is used on Android (Widevine / ClearKey) and iOS
/// (AVContentKey). Values are forwarded verbatim, so provider specific header
/// and token formats can be used without modification.
class RhsDrmConfig {
  /// DRM scheme to activate. Use [RhsDrmType.none] for clear content.
  final RhsDrmType type;

  /// Optional license server endpoint (e.g. Widevine licence URL).
  final String? licenseUrl;

  /// Additional HTTP headers added to license requests.
  final Map<String, String>? headers;

  /// JSON payload for ClearKey on Android. The value is passed directly to
  /// ExoPlayer, so it should contain the base64 encoded key/value pairs.
  final String? clearKey; // JSON as required by ExoPlayer when using ClearKey

  /// Optional content id identifier used by some license servers.
  final String? contentId;

  /// Creates a DRM configuration.
  const RhsDrmConfig({required this.type, this.licenseUrl, this.headers, this.clearKey, this.contentId});

  /// Indicates whether DRM is enabled for the current media.
  bool get isDrm => type != RhsDrmType.none;

  @override
  String toString() =>
      'RhsDrmConfig(type: $type, licenseUrl: $licenseUrl, hasHeaders: ${headers?.isNotEmpty == true}, contentId: $contentId, clearKey: ${clearKey != null ? "***" : null})';
}
