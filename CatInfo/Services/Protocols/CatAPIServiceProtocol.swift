import Cocoa

protocol CatAPIServiceProtocol: Sendable {
    func fetchBreeds() async throws -> [CatBreed]
    func fetchBreedImageInfo(imageId: String) async throws -> CatBreed.BreedImage
    func fetchBreedImageData(info: CatBreed.BreedImage) async throws -> Data
    func searchBreedImages(breedId: String, page: Int, limit: Int) async throws -> [CatBreed.BreedImage]
}
