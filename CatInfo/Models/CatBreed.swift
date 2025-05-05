import Foundation

struct CatBreed: Codable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let temperament: String
    let description: String
    let origin: String
    let weight: Weight
    let lifeSpan: String
    let wikipediaUrl: String?
    let referenceImageId: String?
    let image: BreedImage?
    
    struct Weight: Codable, Equatable, Hashable, Sendable {
        let imperial: String
        let metric: String
    }
    
    struct BreedImage: Codable, Equatable, Hashable, Sendable {
        let id: String?
        let url: String?
        let width: Int?
        let height: Int?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, temperament, description, origin, weight, image
        case lifeSpan = "life_span"
        case wikipediaUrl = "wikipedia_url"
        case referenceImageId = "reference_image_id"
    }
} 
