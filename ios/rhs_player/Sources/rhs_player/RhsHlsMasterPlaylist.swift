import Foundation

struct RhsHlsMasterPlaylist: Sendable {
  struct Variant: Sendable {
    let id: String
    let bitrate: Int
    let width: Int?
    let height: Int?
    let streamInfo: String
    let url: String
  }

  private static let streamInfoPrefix = "#EXT-X-STREAM-INF:"
  private static let attributePattern = try? NSRegularExpression(
    pattern: #"(?:^|[:,])([A-Z0-9-]+)=("[^"]*"|[^,]*)"#)

  let baseURL: URL
  let variants: [Variant]
  private let commonLines: [String]

  init?(text: String, baseURL: URL) {
    let lines = text.split(whereSeparator: \.isNewline).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard lines.first == "#EXTM3U" else { return nil }
    self.baseURL = baseURL
    variants = lines.indices.compactMap { index in
      Self.variant(in: lines, at: index, baseURL: baseURL)
    }
    guard !variants.isEmpty else { return nil }
    commonLines = lines.filter(Self.isCommonLine).map {
      Self.resolveURIAttribute(in: $0, baseURL: baseURL)
    }
  }

  func restricted(to variant: Variant) -> Data {
    let lines = commonLines + [variant.streamInfo, variant.url, ""]
    return Data(lines.joined(separator: "\n").utf8)
  }

  private static func isCommonLine(_ line: String) -> Bool {
    line.hasPrefix("#") && !line.hasPrefix(streamInfoPrefix)
      && !line.hasPrefix("#EXT-X-CONTENT-STEERING:")
      && !line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:")
      && !line.hasPrefix("#EXT-X-IMAGE-STREAM-INF:")
  }

  private static func variant(in lines: [String], at index: Int, baseURL: URL) -> Variant? {
    let line = lines[index]
    guard line.hasPrefix(streamInfoPrefix), lines.indices.contains(index + 1),
      let url = absoluteURI(lines[index + 1], baseURL: baseURL),
      !lines[index + 1].hasPrefix("#")
    else { return nil }
    let bitrate = attributeRange("BANDWIDTH", in: line).flatMap { Int(line[$0]) }
    guard let bitrate, bitrate > 0 else { return nil }
    let size = attributeRange("RESOLUTION", in: line).map { line[$0].split(separator: "x") }
    return Variant(
      id: "hls:\(index)", bitrate: bitrate, width: size?.first.flatMap { Int($0) },
      height: size?.last.flatMap { Int($0) }, streamInfo: line, url: url)
  }

  private static func resolveURIAttribute(in line: String, baseURL: URL) -> String {
    guard let range = attributeRange("URI", in: line),
      line[range].hasPrefix("\""), line[range].hasSuffix("\""),
      let url = absoluteURI(String(line[range].dropFirst().dropLast()), baseURL: baseURL)
    else { return line }
    return line.replacingCharacters(in: range, with: "\"\(url)\"")
  }

  private static func attributeRange(_ key: String, in line: String) -> Range<String.Index>? {
    let matches = attributePattern?.matches(in: line, range: NSRange(line.startIndex..., in: line))
    let match = matches?.first {
      guard let range = Range($0.range(at: 1), in: line) else { return false }
      return line[range] == key
    }
    return match.flatMap { Range($0.range(at: 2), in: line) }
  }

  private static func absoluteURI(_ value: String, baseURL: URL) -> String? {
    let escaped = value.replacingOccurrences(of: "{$", with: "%7B$")
      .replacingOccurrences(of: "}", with: "%7D")
    return URL(string: escaped, relativeTo: baseURL)?.absoluteURL.absoluteString
      .replacingOccurrences(of: "%7B$", with: "{$")
      .replacingOccurrences(of: "%7D", with: "}")
  }
}
