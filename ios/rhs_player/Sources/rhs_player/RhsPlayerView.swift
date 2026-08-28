import AVFoundation
import AVKit
import Flutter
import UIKit

final class RhsPlayerContainerView: UIView {
  weak var playerLayer: AVPlayerLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer?.frame = bounds
  }
}

final class RhsPlayerView: NSObject, FlutterPlatformView, @unchecked Sendable {
  private static let httpHeaderFieldsKey = "AVURLAssetHTTPHeaderFieldsKey"

  private let container: RhsPlayerContainerView
  private let player = AVPlayer()
  private let playerLayer = AVPlayerLayer()
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let tracksChannel: FlutterEventChannel
  private let cuesChannel: FlutterEventChannel
  private let eventHandler = RhsStreamHandler()
  private let tracksHandler = RhsStreamHandler()
  private let cuesHandler = RhsStreamHandler()

  private var eventSink: FlutterEventSink?
  private var tracksSink: FlutterEventSink?
  private var cuesSink: FlutterEventSink?
  private var progressTimer: Timer?
  private var retryWorkItem: DispatchWorkItem?
  private var rebufferWorkItem: DispatchWorkItem?
  private var endObserver: NSObjectProtocol?
  private var failureObserver: NSObjectProtocol?
  private var accessLogObserver: NSObjectProtocol?
  private var statusObservation: NSKeyValueObservation?
  private var timeControlObservation: NSKeyValueObservation?
  private let fairPlayQueue = DispatchQueue(label: "rhsplayer.fairplay")
  private var fairPlayLoader: RhsFairPlayResourceLoader?

  private var sources: [[String: Any]] = []
  private var sourceIndex = 0
  private var currentHeaders: [String: String]?
  private var playbackOptions = RhsPlaybackOptions()
  private var pendingError: String?
  private var desiredRate: Float = 1
  private var retryAttempts = 0
  private var manualVideoBitrate: Double?
  private var manualAudioId: String?
  private var manualSubtitleId: String?
  private var isLooping = false
  private var isDataSaverEnabled = false
  private var shouldBePlaying = false
  private var isDisposed = false

  private lazy var legibleOutput: AVPlayerItemLegibleOutput = {
    let output = AVPlayerItemLegibleOutput()
    output.suppressesPlayerRendering = true
    output.setDelegate(self, queue: .main)
    return output
  }()

  init(
    frame: CGRect,
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    params: [String: Any]?
  ) {
    container = RhsPlayerContainerView(frame: frame)
    methodChannel = FlutterMethodChannel(
      name: "rhsplayer/view_\(viewId)",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "rhsplayer/events_\(viewId)",
      binaryMessenger: messenger
    )
    tracksChannel = FlutterEventChannel(
      name: "rhsplayer/tracks_\(viewId)",
      binaryMessenger: messenger
    )
    cuesChannel = FlutterEventChannel(
      name: "rhsplayer/cues_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    configureView()
    configureChannels()
    observePlayer()
    if let params {
      configure(params)
    }
  }

  func view() -> UIView {
    container
  }

  func dispose() {
    guard !isDisposed else { return }
    isDisposed = true
    shouldBePlaying = false
    player.pause()
    replaceCurrentItem(with: nil)
    fairPlayLoader = nil
    progressTimer?.invalidate()
    progressTimer = nil
    retryWorkItem?.cancel()
    rebufferWorkItem?.cancel()
    removeItemObservers()
    timeControlObservation?.invalidate()
    timeControlObservation = nil
    UIApplication.shared.isIdleTimerDisabled = false
    stopPictureInPicture()
    methodChannel.setMethodCallHandler(nil)
    eventChannel.setStreamHandler(nil)
    tracksChannel.setStreamHandler(nil)
    cuesChannel.setStreamHandler(nil)
  }

  private func configureView() {
    playerLayer.player = player
    playerLayer.videoGravity = .resizeAspect
    container.layer.addSublayer(playerLayer)
    container.playerLayer = playerLayer
    player.actionAtItemEnd = .pause
    player.automaticallyWaitsToMinimizeStalling = true
  }

  private func configureChannels() {
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    configureEventHandler()
    configureTracksHandler()
    configureCuesHandler()
  }

  private func configureEventHandler() {
    eventHandler.onListen = { [weak self] sink in
      guard let self else { return }
      eventSink = sink
      startProgressEvents()
      sendPlaybackEvent()
      sendPendingError()
    }
    eventHandler.onCancel = { [weak self] in
      self?.eventSink = nil
      self?.stopProgressEvents()
    }
    eventChannel.setStreamHandler(eventHandler)
  }

  private func configureTracksHandler() {
    tracksHandler.onListen = { [weak self] sink in
      self?.tracksSink = sink
      self?.sendTracksEvent()
    }
    tracksHandler.onCancel = { [weak self] in
      self?.tracksSink = nil
    }
    tracksChannel.setStreamHandler(tracksHandler)
  }

  private func configureCuesHandler() {
    cuesHandler.onListen = { [weak self] sink in
      self?.cuesSink = sink
      sink(["text": ""])
    }
    cuesHandler.onCancel = { [weak self] in
      self?.cuesSink = nil
    }
    cuesChannel.setStreamHandler(cuesHandler)
  }

  private func observePlayer() {
    timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
      [weak self] _, _ in
      DispatchQueue.main.async {
        self?.handleTimeControlStatusChanged()
      }
    }
  }

  private func configure(_ args: [String: Any]) {
    isLooping = args["loop"] as? Bool ?? false
    isDataSaverEnabled = args["dataSaver"] as? Bool ?? false
    playbackOptions = RhsPlaybackOptions.from(args["playbackOptions"])
    sources = args["playlist"] as? [[String: Any]] ?? []
    let autoPlay = args["autoPlay"] as? Bool ?? true
    shouldBePlaying = args["startAutoPlay"] as? Bool ?? autoPlay
    let startPosition = RhsValue.int(args["startPositionMs"])
    loadSource(at: 0, startPositionMs: startPosition, autoPlay: shouldBePlaying)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      play()
      result(nil)
    case "pause":
      pause()
      result(nil)
    case "seekTo":
      seek(call.arguments)
      result(nil)
    case "setSpeed":
      setSpeed(call.arguments)
      result(nil)
    case "setLooping":
      setLooping(call.arguments)
      result(nil)
    case "setBoxFit":
      setBoxFit(call.arguments)
      result(nil)
    case "retry":
      retry(result: result)
    case "getVideoTracks":
      result(videoTracksPayload())
    case "setVideoTrack":
      setVideoTrack(id: RhsValue.stringArgument(call.arguments, key: "id"))
      result(nil)
    case "getAudioTracks":
      result(audioTracksPayload())
    case "setAudioTrack":
      setAudioTrack(id: RhsValue.stringArgument(call.arguments, key: "id"))
      result(nil)
    case "getSubtitleTracks":
      result(subtitleTracksPayload())
    case "setSubtitleTrack":
      setSubtitleTrack(id: RhsValue.stringArgument(call.arguments, key: "id"))
      result(nil)
    case "enterPip":
      result(startPictureInPicture())
    case "setDataSaver":
      setDataSaver(call.arguments)
      result(nil)
    case "loadMediaSource":
      loadMediaSource(call.arguments)
      result(nil)
    case "dispose":
      dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func play() {
    shouldBePlaying = true
    UIApplication.shared.isIdleTimerDisabled = true
    player.playImmediately(atRate: desiredRate)
  }

  private func pause() {
    shouldBePlaying = false
    player.pause()
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func seek(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    let time = CMTime(value: Int64(RhsValue.int(args["millis"])), timescale: 1000)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  private func setSpeed(_ arguments: Any?) {
    guard let args = arguments as? [String: Any],
      let speed = RhsValue.double(args["speed"]),
      speed > 0
    else { return }
    desiredRate = Float(speed)
    if shouldBePlaying {
      player.playImmediately(atRate: desiredRate)
    }
  }

  private func setLooping(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    isLooping = args["loop"] as? Bool ?? false
  }

  private func setBoxFit(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    switch args["fit"] as? String {
    case "cover":
      playerLayer.videoGravity = .resizeAspectFill
    case "fill":
      playerLayer.videoGravity = .resize
    default:
      playerLayer.videoGravity = .resizeAspect
    }
  }

  private func retry(result: FlutterResult) {
    guard sources.indices.contains(sourceIndex) else {
      result(
        FlutterError(
          code: "NO_SOURCE", message: "Нет источника для повторной загрузки", details: nil))
      return
    }
    retryCurrentSource()
    result(nil)
  }

  private func setDataSaver(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    isDataSaverEnabled = args["enable"] as? Bool ?? false
    if isDataSaverEnabled {
      manualVideoBitrate = nil
    }
    applyPreferredBitrate()
    sendTracksEvent()
  }

  private func loadMediaSource(_ arguments: Any?) {
    guard let args = arguments as? [String: Any],
      let source = args["source"] as? [String: Any]
    else { return }
    sources = [source]
    sourceIndex = 0
    retryAttempts = 0
    shouldBePlaying = args["autoPlay"] as? Bool ?? false
    manualAudioId = nil
    manualSubtitleId = nil
    manualVideoBitrate = nil
    loadSource(at: 0, startPositionMs: 0, autoPlay: shouldBePlaying)
  }

  private func loadSource(at index: Int, startPositionMs: Int, autoPlay: Bool) {
    guard sources.indices.contains(index) else { return }
    let source = sources[index]
    guard let urlString = source["url"] as? String,
      let url = URL(string: urlString)
    else {
      reportError("Некорректный URL медиа-источника")
      return
    }

    sourceIndex = index
    shouldBePlaying = autoPlay
    currentHeaders = RhsValue.stringMap(source["headers"])
    guard let asset = createAsset(url: url, source: source) else { return }
    let item = AVPlayerItem(asset: asset)
    replaceCurrentItem(with: item)
    applyPreferredBitrate()
    observe(item)
    seekAndStart(item: item, positionMs: startPositionMs, autoPlay: autoPlay)
  }

  private func replaceCurrentItem(with item: AVPlayerItem?) {
    player.currentItem?.remove(legibleOutput)
    item?.add(legibleOutput)
    player.replaceCurrentItem(with: item)
  }

  private func createAsset(url: URL, source: [String: Any]) -> AVURLAsset? {
    let asset = AVURLAsset(url: url, options: assetOptions(headers: currentHeaders))
    guard let drm = source["drm"] as? [String: Any] else { return asset }
    let type = drm["type"] as? String ?? "none"
    guard type != "none" else { return asset }
    guard type == "fairPlay" else {
      reportError("DRM \(type) не поддерживается на iOS")
      return nil
    }
    guard let license = drm["licenseUrl"] as? String,
      let licenseUrl = URL(string: license),
      let certificate = drm["certificateUrl"] as? String,
      let certificateUrl = URL(string: certificate)
    else {
      reportError("Для FairPlay нужны licenseUrl и certificateUrl")
      return nil
    }
    let loader = RhsFairPlayResourceLoader(
      licenseUrl: licenseUrl,
      certificateUrl: certificateUrl,
      contentId: drm["contentId"] as? String,
      headers: RhsValue.stringMap(drm["headers"]) ?? [:],
      onError: { [weak self] message in
        DispatchQueue.main.async {
          self?.reportError(message)
        }
      }
    )
    fairPlayLoader = loader
    asset.resourceLoader.setDelegate(loader, queue: fairPlayQueue)
    return asset
  }

  private func assetOptions(headers: [String: String]?) -> [String: Any]? {
    guard let headers, !headers.isEmpty else { return nil }
    return [Self.httpHeaderFieldsKey: headers]
  }

  private func seekAndStart(item: AVPlayerItem, positionMs: Int, autoPlay: Bool) {
    guard positionMs > 0 else {
      if autoPlay { play() } else { pause() }
      return
    }
    let time = CMTime(value: Int64(positionMs), timescale: 1000)
    item.seek(
      to: time,
      completionHandler: { [weak self] _ in
        guard let self else { return }
        if autoPlay { play() } else { pause() }
      })
  }

  private func observe(_ item: AVPlayerItem) {
    removeItemObservers()
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        self?.handleStatus(item.status, error: item.error)
      }
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.handleItemEnded()
    }
    failureObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] notification in
      let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self?.handleItemFailure(error)
    }
    accessLogObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemNewAccessLogEntry,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.sendTracksEvent()
    }
  }

  private func removeItemObservers() {
    statusObservation?.invalidate()
    statusObservation = nil
    for observer in [endObserver, failureObserver, accessLogObserver] {
      if let observer {
        NotificationCenter.default.removeObserver(observer)
      }
    }
    endObserver = nil
    failureObserver = nil
    accessLogObserver = nil
  }

  private func handleStatus(_ status: AVPlayerItem.Status, error: Error?) {
    switch status {
    case .readyToPlay:
      retryAttempts = 0
      retryWorkItem?.cancel()
      sendTracksEvent()
      sendPlaybackEvent()
    case .failed:
      handleItemFailure(error)
    case .unknown:
      break
    @unknown default:
      break
    }
  }

  private func handleItemEnded() {
    let nextIndex = sourceIndex + 1
    if sources.indices.contains(nextIndex) {
      loadSource(at: nextIndex, startPositionMs: 0, autoPlay: true)
      return
    }
    if isLooping, !sources.isEmpty {
      loadSource(at: 0, startPositionMs: 0, autoPlay: true)
      return
    }
    shouldBePlaying = false
    UIApplication.shared.isIdleTimerDisabled = false
    sendPlaybackEvent()
  }

  private func handleItemFailure(_ error: Error?) {
    let message = error?.localizedDescription ?? "Ошибка воспроизведения AVPlayer"
    reportError(message)
    scheduleRetryIfNeeded()
  }

  private func retryCurrentSource() {
    let position = currentPositionMs
    loadSource(at: sourceIndex, startPositionMs: position, autoPlay: shouldBePlaying)
  }

  private func scheduleRetryIfNeeded() {
    guard playbackOptions.autoRetry,
      playbackOptions.maxRetryCount < 0 || retryAttempts < playbackOptions.maxRetryCount
    else { return }
    retryAttempts += 1
    let multiplier = pow(2.0, Double(retryAttempts - 1))
    let delay = min(playbackOptions.initialRetryDelay * multiplier, playbackOptions.maxRetryDelay)
    retryWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.retryCurrentSource()
    }
    retryWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func handleTimeControlStatusChanged() {
    sendPlaybackEvent()
    guard player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
      shouldBePlaying,
      let timeout = playbackOptions.rebufferTimeout
    else {
      rebufferWorkItem?.cancel()
      rebufferWorkItem = nil
      return
    }
    guard rebufferWorkItem == nil else { return }
    let workItem = DispatchWorkItem { [weak self] in
      self?.rebufferWorkItem = nil
      self?.retryCurrentSource()
    }
    rebufferWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
  }

  private func reportError(_ message: String) {
    pendingError = message
    sendPlaybackEvent(error: message)
  }

  private func sendPendingError() {
    guard let pendingError else { return }
    sendPlaybackEvent(error: pendingError)
  }

  private var currentPositionMs: Int {
    RhsValue.milliseconds(player.currentTime())
  }

  private func startProgressEvents() {
    progressTimer?.invalidate()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
      [weak self] _ in
      self?.sendPlaybackEvent()
    }
  }

  private func stopProgressEvents() {
    progressTimer?.invalidate()
    progressTimer = nil
  }

  private func sendPlaybackEvent(error: String? = nil) {
    guard let eventSink else { return }
    let item = player.currentItem
    var payload: [String: Any] = [
      "positionMs": currentPositionMs,
      "durationMs": RhsValue.milliseconds(item?.duration),
      "bufferedPositionMs": bufferedPositionMs(item),
      "isBuffering": player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
      "isPlaying": player.timeControlStatus == .playing,
    ]
    payload["error"] = error ?? pendingError ?? NSNull()
    eventSink(payload)
    if error == nil, item?.status == .readyToPlay {
      pendingError = nil
    }
  }

  private func bufferedPositionMs(_ item: AVPlayerItem?) -> Int {
    guard let ranges = item?.loadedTimeRanges else { return 0 }
    return ranges.reduce(0) { result, value in
      let range = value.timeRangeValue
      return max(result, RhsValue.milliseconds(CMTimeRangeGetEnd(range)))
    }
  }

  private func applyPreferredBitrate() {
    guard let item = player.currentItem else { return }
    if let manualVideoBitrate {
      item.preferredPeakBitRate = manualVideoBitrate
    } else {
      item.preferredPeakBitRate = isDataSaverEnabled ? 800_000 : 0
    }
  }

  private func stopPictureInPicture() {
    if pipController?.isPictureInPictureActive == true {
      pipController?.stopPictureInPicture()
    }
    pipController = nil
  }

  private var pipController: AVPictureInPictureController?

  private func startPictureInPicture() -> Bool {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
    if pipController == nil {
      pipController = AVPictureInPictureController(playerLayer: playerLayer)
      pipController?.delegate = self
      if #available(iOS 14.2, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
      }
    }
    guard let pipController, pipController.isPictureInPicturePossible else { return false }
    if !pipController.isPictureInPictureActive {
      pipController.startPictureInPicture()
    }
    return true
  }

  private func videoTracksPayload() -> [[String: Any]] {
    guard let item = player.currentItem else { return [] }
    var bitrates = Set<Double>()
    for event in item.accessLog()?.events ?? [] where event.indicatedBitrate > 0 {
      bitrates.insert(event.indicatedBitrate)
    }
    if let manualVideoBitrate {
      bitrates.insert(manualVideoBitrate)
    }
    let active = manualVideoBitrate ?? item.accessLog()?.events.last?.indicatedBitrate ?? 0
    return bitrates.sorted(by: >).map { bitrate in
      [
        "id": String(Int(bitrate)),
        "label": RhsValue.bitrateLabel(bitrate),
        "bitrate": Int(bitrate),
        "width": NSNull(),
        "height": NSNull(),
        "selected": RhsValue.nearlyEqual(bitrate, active),
      ]
    }
  }

  private func setVideoTrack(id: String?) {
    guard let id, let bitrate = Double(id), bitrate > 0 else {
      manualVideoBitrate = nil
      applyPreferredBitrate()
      sendTracksEvent()
      return
    }
    manualVideoBitrate = bitrate
    applyPreferredBitrate()
    sendTracksEvent()
  }

  private func audioTracksPayload() -> [[String: Any]] {
    mediaTracksPayload(characteristic: .audible, prefix: "audible")
  }

  private func subtitleTracksPayload() -> [[String: Any]] {
    mediaTracksPayload(characteristic: .legible, prefix: "legible")
  }

  private func mediaTracksPayload(
    characteristic: AVMediaCharacteristic,
    prefix: String
  ) -> [[String: Any]] {
    guard let item = player.currentItem,
      let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic)
    else { return [] }
    let selected = item.currentMediaSelection.selectedMediaOption(in: group)
    return group.options.enumerated().map { index, option in
      var payload: [String: Any] = [
        "id": "\(prefix):\(index)",
        "label": option.displayName,
        "language": RhsValue.language(option) as Any,
        "selected": option == selected,
      ]
      if characteristic == .legible {
        payload["forced"] = option.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
      }
      return payload
    }
  }

  private func setAudioTrack(id: String?) {
    selectMediaOption(id: id, characteristic: .audible, selectDefaultWhenNil: true)
    manualAudioId = id
  }

  private func setSubtitleTrack(id: String?) {
    selectMediaOption(id: id, characteristic: .legible, selectDefaultWhenNil: false)
    manualSubtitleId = id
    if id == nil {
      cuesSink?(["text": ""])
    }
  }

  private func selectMediaOption(
    id: String?,
    characteristic: AVMediaCharacteristic,
    selectDefaultWhenNil: Bool
  ) {
    guard let item = player.currentItem,
      let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic)
    else { return }
    let option = mediaOption(id: id, group: group)
    item.select(option ?? (selectDefaultWhenNil ? group.defaultOption : nil), in: group)
    sendTracksEvent()
  }

  private func mediaOption(id: String?, group: AVMediaSelectionGroup) -> AVMediaSelectionOption? {
    guard let id else { return nil }
    let components = id.split(separator: ":")
    guard components.count == 2,
      let index = Int(components[1]),
      group.options.indices.contains(index)
    else { return nil }
    return group.options[index]
  }

  private func sendTracksEvent() {
    tracksSink?([
      "video": videoTracksPayload(),
      "audio": audioTracksPayload(),
      "subtitle": subtitleTracksPayload(),
    ])
  }
}

extension RhsPlayerView: AVPlayerItemLegibleOutputPushDelegate {
  func legibleOutput(
    _ output: AVPlayerItemLegibleOutput,
    didOutputAttributedStrings strings: [NSAttributedString],
    nativeSampleBuffers: [Any],
    forItemTime itemTime: CMTime
  ) {
    let text = strings.map(\.string).joined(separator: "\n")
    cuesSink?(["text": text])
  }
}

extension RhsPlayerView: AVPictureInPictureControllerDelegate {}

private final class RhsStreamHandler: NSObject, FlutterStreamHandler {
  var onListen: ((@escaping FlutterEventSink) -> Void)?
  var onCancel: (() -> Void)?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    onListen?(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancel?()
    return nil
  }
}

private struct RhsPlaybackOptions {
  let maxRetryCount: Int
  let initialRetryDelay: TimeInterval
  let maxRetryDelay: TimeInterval
  let autoRetry: Bool
  let rebufferTimeout: TimeInterval?

  init(
    maxRetryCount: Int = 3,
    initialRetryDelay: TimeInterval = 1,
    maxRetryDelay: TimeInterval = 10,
    autoRetry: Bool = true,
    rebufferTimeout: TimeInterval? = nil
  ) {
    self.maxRetryCount = maxRetryCount
    self.initialRetryDelay = initialRetryDelay
    self.maxRetryDelay = maxRetryDelay
    self.autoRetry = autoRetry
    self.rebufferTimeout = rebufferTimeout
  }

  static func from(_ value: Any?) -> RhsPlaybackOptions {
    guard let map = value as? [String: Any] else { return RhsPlaybackOptions() }
    let rebufferMs = RhsValue.optionalInt(map["rebufferTimeoutMs"])
    return RhsPlaybackOptions(
      maxRetryCount: RhsValue.int(map["maxRetryCount"], fallback: 3),
      initialRetryDelay: TimeInterval(RhsValue.int(map["initialRetryDelayMs"], fallback: 1000))
        / 1000,
      maxRetryDelay: TimeInterval(RhsValue.int(map["maxRetryDelayMs"], fallback: 10000)) / 1000,
      autoRetry: map["autoRetry"] as? Bool ?? true,
      rebufferTimeout: rebufferMs.map { TimeInterval($0) / 1000 }
    )
  }
}

private enum RhsValue {
  static func int(_ value: Any?, fallback: Int = 0) -> Int {
    optionalInt(value) ?? fallback
  }

  static func optionalInt(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    return (value as? NSNumber)?.intValue
  }

  static func double(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    return (value as? NSNumber)?.doubleValue
  }

  static func stringArgument(_ arguments: Any?, key: String) -> String? {
    (arguments as? [String: Any])?[key] as? String
  }

  static func stringMap(_ value: Any?) -> [String: String]? {
    guard let values = value as? [String: Any] else { return nil }
    let result = values.reduce(into: [String: String]()) { map, entry in
      if let string = entry.value as? String {
        map[entry.key] = string
      }
    }
    return result.isEmpty ? nil : result
  }

  static func milliseconds(_ time: CMTime?) -> Int {
    guard let time else { return 0 }
    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite, seconds >= 0 else { return 0 }
    return Int(seconds * 1000)
  }

  static func bitrateLabel(_ bitrate: Double) -> String {
    let megabits = bitrate / 1_000_000
    if megabits >= 1 {
      return String(format: megabits >= 10 ? "%.0f Mbps" : "%.1f Mbps", megabits)
    }
    return String(format: "%.0f Kbps", bitrate / 1000)
  }

  static func nearlyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
    guard lhs != rhs else { return true }
    guard lhs > 0, rhs > 0 else { return abs(lhs - rhs) < 50_000 }
    return abs(lhs - rhs) / max(lhs, rhs) < 0.05
  }

  static func language(_ option: AVMediaSelectionOption) -> Any {
    if let language = option.extendedLanguageTag { return language }
    if let identifier = option.locale?.identifier { return identifier }
    return NSNull()
  }
}
