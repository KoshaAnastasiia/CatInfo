import Cocoa

final class CatDetailViewModel: Sendable {
    private let apiService: CatAPIServiceProtocol
    private let cacheService: ImageCacheServiceProtocol
    private(set) var selectedBreed: CatBreed?
    private(set) var isLoadingImage = false
    
    weak var delegate: CatDetailViewModelDelegate?
    
    var onImageLoaded: ((NSImage?) -> Void)?
    var onBreedDetailsUpdated: (() -> Void)?
    var onError: ((String) -> Void)?
    
    init(
        apiService: CatAPIServiceProtocol,
        cacheService: ImageCacheServiceProtocol
    ) {
        self.apiService = apiService
        self.cacheService = cacheService
    }
    
    func setBreed(_ breed: CatBreed) {
        self.selectedBreed = breed
        delegate?.didUpdateBreedDetails()
        onBreedDetailsUpdated?()
        
        loadBreedImage()
    }
    
    var name: String {
        return selectedBreed?.name ?? ""
    }
    
    var origin: String {
        guard let origin = selectedBreed?.origin else { return "" }
        return "Origin: \(origin)"
    }
    
    var temperament: String {
        guard let temperament = selectedBreed?.temperament else { return "" }
        return "Temperament: \(temperament)"
    }
    
    var descriptionText: String {
        return selectedBreed?.description ?? ""
    }
    
    var weight: String {
        guard let weightMetric = selectedBreed?.weight.metric else { return "" }
        return "Weight: \(weightMetric) kg"
    }
    
    var lifeSpan: String {
        guard let lifeSpan = selectedBreed?.lifeSpan else { return "" }
        return "Life Span: \(lifeSpan) years"
    }
    
    var hasWikipediaLink: Bool {
        return selectedBreed?.wikipediaUrl != nil
    }
    
    var breedId: String? {
        return selectedBreed?.id
    }
    
    func openWikipedia() {
        guard let urlString = selectedBreed?.wikipediaUrl,
              let url = URL(string: urlString) else {
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    private func updateImageLoading(image: NSImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoadingImage = false
            self.delegate?.didLoadImage(image)
            self.onImageLoaded?(image)
        }
    }
    
    private func loadBreedImage() {
        guard let imageId = selectedBreed?.referenceImageId else {
            self.delegate?.didLoadImage(nil)
            self.onImageLoaded?(nil)
            return
        }
        
        isLoadingImage = true
        
        Task {
            // First, try to load from cache using image ID
            if let cachedImage = await cacheService.getImage(forKey: imageId) {
                updateImageLoading(image: cachedImage)
                return
            }
            
            // If not in cache, fetch image info from API
            do {
                let imageInfo = try await apiService.fetchBreedImageInfo(imageId: imageId)
                
                // Try URL-based cache key
                if let imageUrl = imageInfo.url {
                    let urlCacheKey = type(of: cacheService).makeCacheKey(from: imageUrl)
                    
                    if let cachedImage = await cacheService.getImage(forKey: urlCacheKey) {
                        updateImageLoading(image: cachedImage)
                        return
                    }
                }
                
                let imageData = try await apiService.fetchBreedImageData(info: imageInfo)
                if let image = NSImage(data: imageData) {
                    cacheService.saveImage(image, forKey: imageId)
                    
                    if let imageUrl = imageInfo.url {
                        let urlCacheKey = type(of: cacheService).makeCacheKey(from: imageUrl)
                        cacheService.saveImage(image, forKey: urlCacheKey)
                    }
                    updateImageLoading(image: image)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoadingImage = false
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }
}


extension NSImage : @unchecked @retroactive Sendable {
}
