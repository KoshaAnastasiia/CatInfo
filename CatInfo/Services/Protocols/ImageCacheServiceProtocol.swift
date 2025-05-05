import Cocoa

protocol ImageCacheServiceProtocol: Sendable {
    func getImage(forKey key: String) -> NSImage?
    func saveImage(_ image: NSImage, forKey key: String)
    func saveImageData(_ data: Data, forKey key: String)
    func clearCache()
    
    static func makeCacheKey(from urlString: String) -> String
    static func makeCacheKey(for breedImage: CatBreed.BreedImage) -> String?
}
