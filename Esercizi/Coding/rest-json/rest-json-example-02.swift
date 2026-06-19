// Union Type con Dodacle

// MARK: - Domain types

struct DigitalProduct: Codable, Sendable {
    let id: UUID
    let name: String
    let downloadURL: URL
    let fileSizeMB: Double
}

struct PhysicalProduct: Codable, Sendable {
    let id: UUID
    let name: String
    let weightKg: Double
    let dimensions: Dimensions
}

struct Dimensions: Codable, Sendable {
    let width, height, depth: Double
}

// MARK: - Union type

enum CatalogProduct: Sendable {
    case digital(DigitalProduct)
    case physical(PhysicalProduct)
}

extension CatalogProduct: Codable {
    private enum CodingKeys: String, CodingKey { case type }
    private enum ProductType: String, Codable { case digital, physical }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ProductType.self, forKey: .type)

        let singleContainer = try decoder.singleValueContainer()
        switch type_ {
        case .digital:
            self = .digital(try singleContainer.decode(DigitalProduct.self))
        case .physical:
            self = .physical(try singleContainer.decode(PhysicalProduct.self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .digital(let p): try p.encode(to: encoder)
        case .physical(let p): try p.encode(to: encoder)
        }
    }
}

// MARK: - Test di decodifica

func demoCodableUnionType() throws {
    let digitalJSON = Data("""
    {"type":"digital","id":"00000000-0000-0000-0000-000000000001",
     "name":"Corso Swift","downloadURL":"https://example.com/file.zip","fileSizeMB":245.5}
    """.utf8)

    let physicalJSON = Data("""
    {"type":"physical","id":"00000000-0000-0000-0000-000000000002",
     "name":"iPhone Case","weightKg":0.15,"dimensions":{"width":7.5,"height":15.2,"depth":0.8}}
    """.utf8)

    let decoder = JSONDecoder()
    let digital = try decoder.decode(CatalogProduct.self, from: digitalJSON)
    let physical = try decoder.decode(CatalogProduct.self, from: physicalJSON)

    if case .digital(let d) = digital { print("Digital: \(d.name), \(d.fileSizeMB) MB") }
    if case .physical(let p) = physical { print("Physical: \(p.name), \(p.weightKg) kg") }
}