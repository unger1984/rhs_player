import AVFoundation
import Foundation

final class RhsFairPlayResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
  private let licenseUrl: URL
  private let certificateUrl: URL
  private let contentId: String?
  private let headers: [String: String]
  private let onError: (String) -> Void
  private let session: URLSession
  private var certificateData: Data?

  init(
    licenseUrl: URL,
    certificateUrl: URL,
    contentId: String?,
    headers: [String: String],
    onError: @escaping (String) -> Void
  ) {
    self.licenseUrl = licenseUrl
    self.certificateUrl = certificateUrl
    self.contentId = contentId
    self.headers = headers
    self.onError = onError
    session = URLSession(configuration: .ephemeral)
    super.init()
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
  ) -> Bool {
    guard loadingRequest.request.url?.scheme?.lowercased() == "skd" else { return false }
    loadKey(for: loadingRequest)
    return true
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest
  ) -> Bool {
    loadKey(for: renewalRequest)
    return true
  }

  private func loadKey(for loadingRequest: AVAssetResourceLoadingRequest) {
    loadCertificate { [weak self] result in
      guard let self else { return }
      switch result {
      case .success(let certificate):
        requestContentKey(loadingRequest, certificate: certificate)
      case .failure(let error):
        finish(loadingRequest, error: error)
      }
    }
  }

  private func loadCertificate(completion: @escaping (Result<Data, Error>) -> Void) {
    if let certificateData {
      completion(.success(certificateData))
      return
    }

    var request = URLRequest(url: certificateUrl, cachePolicy: .reloadIgnoringLocalCacheData)
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    applyHeaders(to: &request)
    session.dataTask(with: request) { [weak self] data, response, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let data, !data.isEmpty else {
        completion(.failure(RhsFairPlayError.emptyCertificate))
        return
      }
      guard RhsFairPlayResourceLoader.isSuccessful(response) else {
        completion(.failure(RhsFairPlayError.httpStatus(response)))
        return
      }
      self?.certificateData = data
      completion(.success(data))
    }.resume()
  }

  private func requestContentKey(
    _ loadingRequest: AVAssetResourceLoadingRequest,
    certificate: Data
  ) {
    do {
      let identifier = try contentIdentifier(for: loadingRequest)
      let identifierData = Data(identifier.utf8)
      let spc = try loadingRequest.streamingContentKeyRequestData(
        forApp: certificate,
        contentIdentifier: identifierData,
        options: nil
      )
      requestLicense(spc: spc, contentIdentifier: identifier) { [weak self] result in
        guard let self else { return }
        switch result {
        case .success(let ckc):
          loadingRequest.dataRequest?.respond(with: ckc)
          loadingRequest.finishLoading()
        case .failure(let error):
          finish(loadingRequest, error: error)
        }
      }
    } catch {
      finish(loadingRequest, error: error)
    }
  }

  private func contentIdentifier(for loadingRequest: AVAssetResourceLoadingRequest) throws -> String
  {
    if let contentId, !contentId.isEmpty { return contentId }
    if let host = loadingRequest.request.url?.host, !host.isEmpty { return host }
    throw RhsFairPlayError.missingContentIdentifier
  }

  private func requestLicense(
    spc: Data,
    contentIdentifier: String,
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    let body: [String: String] = [
      "content_id": percentEncode(contentIdentifier),
      "spc_message": spc.base64EncodedString(),
    ]
    guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
      completion(.failure(RhsFairPlayError.invalidLicenseRequest))
      return
    }

    var request = URLRequest(url: licenseUrl, cachePolicy: .reloadIgnoringLocalCacheData)
    request.httpMethod = "POST"
    request.httpBody = bodyData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    applyHeaders(to: &request)
    session.dataTask(with: request) { data, response, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard RhsFairPlayResourceLoader.isSuccessful(response) else {
        completion(.failure(RhsFairPlayError.httpStatus(response)))
        return
      }
      guard let data, let ckc = RhsFairPlayResourceLoader.decodeCkc(data) else {
        completion(.failure(RhsFairPlayError.invalidLicenseResponse))
        return
      }
      completion(.success(ckc))
    }.resume()
  }

  private func applyHeaders(to request: inout URLRequest) {
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
  }

  private func percentEncode(_ value: String) -> String {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }

  private func finish(_ loadingRequest: AVAssetResourceLoadingRequest, error: Error) {
    onError("FairPlay: \(error.localizedDescription)")
    loadingRequest.finishLoading(with: error)
  }

  private static func isSuccessful(_ response: URLResponse?) -> Bool {
    guard let response = response as? HTTPURLResponse else { return true }
    return (200...299).contains(response.statusCode)
  }

  private static func decodeCkc(_ data: Data) -> Data? {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let value = json["ckc_message"] as? String
    {
      return Data(base64Encoded: value)
    }
    if let text = String(data: data, encoding: .utf8) {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("<ckc>"), trimmed.hasSuffix("</ckc>") {
        return Data(base64Encoded: String(trimmed.dropFirst(5).dropLast(6)))
      }
    }
    return data.isEmpty ? nil : data
  }
}

private enum RhsFairPlayError: LocalizedError {
  case emptyCertificate
  case httpStatus(URLResponse?)
  case invalidLicenseRequest
  case invalidLicenseResponse
  case missingContentIdentifier

  var errorDescription: String? {
    switch self {
    case .emptyCertificate:
      return "сертификат пуст"
    case .httpStatus(let response):
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      return "сервер вернул HTTP \(status)"
    case .invalidLicenseRequest:
      return "не удалось сформировать SPC-запрос"
    case .invalidLicenseResponse:
      return "ответ license server не содержит CKC"
    case .missingContentIdentifier:
      return "в skd:// URL отсутствует content ID"
    }
  }
}
