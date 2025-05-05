import Cocoa

final class CatAPIService: CatAPIServiceProtocol {
    private let apiKey = "live_XS9glB3mWLFaBTGfY69ZPaRijdTFVszpg0mUjbISRNOjir5zHDAnjS5g2fBmZBdg"
    private let baseURL = "https://api.thecatapi.com/v1"
    private let session: URLSession
    private let cacheService: ImageCacheServiceProtocol
    
    init(session: URLSession = .shared, cacheService: ImageCacheServiceProtocol) {
        self.session = session
        self.cacheService = cacheService
    }

    func fetchBreeds() async throws -> [CatBreed] {
        let url = URL(string: "\(baseURL)/breeds")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode([CatBreed].self, from: data)
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchBreedImageInfo(imageId: String) async throws -> CatBreed.BreedImage {
        let url = URL(string: "\(baseURL)/images/\(imageId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(CatBreed.BreedImage.self, from: data)
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchBreedImageData(info: CatBreed.BreedImage) async throws -> Data {
        guard let imageUrlString = info.url,
              let imageUrl = URL(string: imageUrlString) else {
            throw APIError.invalidURL
        }
        
        let cacheKey = type(of: cacheService).makeCacheKey(from: imageUrlString)
        
        if let cachedImage = cacheService.getImage(forKey: cacheKey) {
            if let tiffData = cachedImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                return jpegData
            }
        }
        
        let (imageData, imageResponse) = try await session.data(from: imageUrl)
        
        guard let httpImageResponse = imageResponse as? HTTPURLResponse,
              (200...299).contains(httpImageResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        cacheService.saveImageData(imageData, forKey: cacheKey)
        
        return imageData
    }

    func searchBreedImages(breedId: String, page: Int = 0, limit: Int = 10) async throws -> [CatBreed.BreedImage] {
        let urlComponents = NSURLComponents(string: "\(baseURL)/images/search")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "breed_ids", value: breedId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode([CatBreed.BreedImage].self, from: data)
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(statusCode: Int)
    case decodingError(DecodingError)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - invalid API key"
        case .notFound:
            return "Resource not found"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let decodingError):
            return "Failed to parse response: \(decodingError.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 
