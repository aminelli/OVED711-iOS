// APIClient type-safe con Edpoint Protocol

import Foundation


// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE", patch = "PATCH"
}

// MARK: - Endpoint protocol

protocol Endpoint {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var body: (any Encodable)? { get }
    var headers: [String: String] { get }
}

extension Endpoint {
    var scheme: String { "https" }
    var host: String { "api.example.com" }
    var queryItems: [URLQueryItem] { [] }
    var body: (any Encodable)? { nil }
    var headers: [String: String] { ["Content-Type": "application/json"] }

    func asURLRequest(encoder: JSONEncoder = .init()) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        if !queryItems.isEmpty { components.queryItems = queryItems }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL
    case clientError(statusCode: Int, data: Data)
    case serverError(statusCode: Int)
    case decodingError(Error)
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL non valido"
        case .clientError(let code, _): return "Errore client: \(code)"
        case .serverError(let code): return "Errore server: \(code)"
        case .decodingError(let err): return "Parsing fallito: \(err.localizedDescription)"
        case .timeout: return "Richiesta scaduta"
        case .unknown(let err): return err.localizedDescription
        }
    }
}

// MARK: - APIClient

actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared,
         decoder: JSONDecoder = .init(),
         encoder: JSONEncoder = .init()) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func request<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let request = try endpoint.asURLRequest(encoder: encoder)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.unknown(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 400..<500:
            throw APIError.clientError(statusCode: http.statusCode, data: data)
        default:
            throw APIError.serverError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Endpoint concreti

struct CreateCartRequest: Encodable {
    let productID: UUID
    let quantity: Int
}

struct CartResponse: Decodable, Sendable {
    let cartID: UUID
    let total: Double
}

struct ProductsPage: Decodable, Sendable {
    let items: [ProductSummary]
    let nextCursor: String?
    let hasMore: Bool
}

struct ProductSummary: Decodable, Sendable {
    let id: UUID
    let name: String
    let price: Double
}

enum ShopEndpoint: Endpoint {
    case listProducts(page: Int, limit: Int = 20)
    case createCart(request: CreateCartRequest)

    var path: String {
        switch self {
        case .listProducts: return "/products"
        case .createCart: return "/cart"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listProducts: return .get
        case .createCart: return .post
        }
    }

    var queryItems: [URLQueryItem] {
        if case .listProducts(let page, let limit) = self {
            return [.init(name: "page", value: "\(page)"),
                    .init(name: "limit", value: "\(limit)")]
        }
        return []
    }

    var body: (any Encodable)? {
        if case .createCart(let req) = self { return req }
        return nil
    }
}

// MARK: - Uso

func demoAPIClient() async {
    let client = APIClient()
    do {
        let page: ProductsPage = try await client.request(ShopEndpoint.listProducts(page: 1))
        print("Prodotti ricevuti: \(page.items.count), hasMore: \(page.hasMore)")

        let cartReq = CreateCartRequest(productID: UUID(), quantity: 2)
        let cart: CartResponse = try await client.request(ShopEndpoint.createCart(request: cartReq))
        print("Carrello creato: \(cart.cartID), totale: \(cart.total)")
    } catch let error as APIError {
        print("Errore API: \(error.errorDescription ?? "")")
    } catch {
        print("Errore sconosciuto: \(error)")
    }
}