//
//  Network.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 4/3/22.
//

import Foundation

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct Request {
    let url: String
    let method: HTTPMethod
    var parameters: [String: String]?
    var headers: [String: String]?
}

enum G4OError: Error {
    case invalidURL
    case networkProblem(Error?)
    case badStatusCode(Int)
    case emptyResponse
    case parseProblems
}

extension G4OError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "error.invalidURL".translated
        case .networkProblem(let underlying):
            return underlying?.localizedDescription ?? "error.network".translated
        case .badStatusCode(let code):
            return "error.badStatusCode".translated(code)
        case .emptyResponse:
            return "error.emptyResponse".translated
        case .parseProblems:
            return "error.parse".translated
        }
    }
}

final class Network: Sendable {

    /// `sedeaplicaciones.minetur.gob.es` aborts the handshake when the client offers TLS 1.3, and it
    /// only negotiates DHE/static-RSA cipher suites (no ECDHE). Capping the maximum version here is
    /// what makes the request succeed; the lack of forward secrecy is covered by the ATS exception
    /// declared in the Info.plist of each target.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    func perform(_ request: Request) async throws(G4OError) -> Data {
        guard var components = URLComponents(string: request.url) else {
            throw .invalidURL
        }
        if let parameters = request.parameters, !parameters.isEmpty {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw .invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        request.headers?.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Network.session.data(for: urlRequest)
        } catch {
            throw .networkProblem(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw .badStatusCode(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw .emptyResponse
        }
        return data
    }
}
