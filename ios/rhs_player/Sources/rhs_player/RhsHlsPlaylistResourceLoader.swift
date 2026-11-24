import AVFoundation
import Foundation

final class RhsHlsPlaylistResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
  let url: URL
  private let playlist: Data
  private let fairPlay: RhsFairPlayResourceLoader?

  init?(master: RhsHlsMasterPlaylist, variant: RhsHlsMasterPlaylist.Variant,
        fairPlay: RhsFairPlayResourceLoader?) {
    var components = URLComponents(url: master.baseURL, resolvingAgainstBaseURL: false)
    components?.scheme = "rhs-hls"
    if master.baseURL.pathExtension.lowercased() != "m3u8" {
      components?.path += "/playlist.m3u8"
    }
    guard let url = components?.url else { return nil }
    self.url = url
    self.playlist = master.restricted(to: variant)
    self.fairPlay = fairPlay
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest
  ) -> Bool {
    guard request.request.url == url else {
      return fairPlay?.resourceLoader(
        resourceLoader, shouldWaitForLoadingOfRequestedResource: request) ?? false
    }
    request.contentInformationRequest?.contentType = "public.m3u-playlist"
    request.contentInformationRequest?.contentLength = Int64(playlist.count)
    request.contentInformationRequest?.isByteRangeAccessSupported = true
    if let dataRequest = request.dataRequest {
      let start = Int(dataRequest.currentOffset)
      if start >= 0, start < playlist.count {
        let length = dataRequest.requestsAllDataToEndOfResource
          ? playlist.count - start : min(dataRequest.requestedLength, playlist.count - start)
        dataRequest.respond(with: playlist.subdata(in: start..<(start + length)))
      }
    }
    request.finishLoading()
    return true
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForRenewalOfRequestedResource request: AVAssetResourceRenewalRequest
  ) -> Bool {
    fairPlay?.resourceLoader(
      resourceLoader, shouldWaitForRenewalOfRequestedResource: request) ?? false
  }
}
