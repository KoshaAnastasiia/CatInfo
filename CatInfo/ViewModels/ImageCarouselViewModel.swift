import Cocoa

final class ImageCarouselViewModel: Sendable {
    private let apiService: CatAPIServiceProtocol
    private let cacheService: ImageCacheServiceProtocol
    private let breedId: String
    
    private var images: [CatBreed.BreedImage] = []
    private var currentPage = 0
    private var currentImageIndex = 0
    private let imagesPerPage = 10
    
    private(set) var isLoading = false
    private(set) var isImageLoading = false
    
    weak var delegate: ImageCarouselViewModelDelegate?
    
    var onImagesLoaded: (() -> Void)?
    var onCurrentImageUpdated: ((NSImage?) -> Void)?
    var onPageInfoUpdated: ((String) -> Void)?
    var onNavigationStateChanged: ((Bool, Bool) -> Void)?
    var onError: ((String) -> Void)?
    
    init(
        breedId: String,
        apiService: CatAPIServiceProtocol,
        cacheService: ImageCacheServiceProtocol
    ) {
        self.breedId = breedId
        self.apiService = apiService
        self.cacheService = cacheService
    }
    
    func loadImages() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let fetchedImages = try await apiService.searchBreedImages(
                    breedId: breedId,
                    page: currentPage,
                    limit: imagesPerPage
                )
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.images = fetchedImages
                    self.isLoading = false
                    self.updateUI()
                    
                    self.delegate?.didFinishLoading()
                    self.onImagesLoaded?()
                    
                    if !fetchedImages.isEmpty {
                        self.showImage(at: 0)
                    } else {
                        let noImagesMessage = "No images available for this breed"
                        self.delegate?.didUpdatePageInfo(noImagesMessage)
                        self.onPageInfoUpdated?(noImagesMessage)
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    let errorMessage = "Failed to load images: \(error.localizedDescription)"
                    self.delegate?.didEncounterError(errorMessage)
                    self.onError?(errorMessage)
                }
            }
        }
    }
    
    private func loadMoreImages() {
        currentPage += 1
        
        Task {
            do {
                let fetchedImages = try await apiService.searchBreedImages(
                    breedId: breedId,
                    page: currentPage,
                    limit: imagesPerPage
                )
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.images.append(contentsOf: fetchedImages)
                    self.updateUI()
                }
            } catch {
                currentPage -= 1
            }
        }
    }
    
    func showNextImage() {
        if currentImageIndex < images.count - 1 {
            showImage(at: currentImageIndex + 1)
        }
    }
    
    func showPreviousImage() {
        if currentImageIndex > 0 {
            showImage(at: currentImageIndex - 1)
        }
    }

    private func showImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        
        currentImageIndex = index
        
        if currentImageIndex >= images.count - 3 {
            loadMoreImages()
        }
        
        isImageLoading = true
        
        let image = images[index]
        guard let imageUrl = image.url else {
            isImageLoading = false
            delegate?.didUpdateCurrentImage(nil)
            onCurrentImageUpdated?(nil)
            delegate?.didUpdatePageInfo("Image unavailable")
            onPageInfoUpdated?("Image unavailable")
            return
        }
        
        let cacheKey = type(of: cacheService).makeCacheKey(from: imageUrl)
        
        if let cachedImage = cacheService.getImage(forKey: cacheKey) {
            isImageLoading = false
            delegate?.didUpdateCurrentImage(cachedImage)
            onCurrentImageUpdated?(cachedImage)
            updateUI()
            return
        }
        
        Task {
            do {
                let imageData = try await apiService.fetchBreedImageData(info: image)
                if let nsImage = NSImage(data: imageData) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.isImageLoading = false
                        self.delegate?.didUpdateCurrentImage(nsImage)
                        self.onCurrentImageUpdated?(nsImage)
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isImageLoading = false
                    self.delegate?.didUpdatePageInfo("Failed to load image")
                    self.onPageInfoUpdated?("Failed to load image")
                    self.delegate?.didEncounterError("Failed to load image: \(error.localizedDescription)")
                    self.onError?("Failed to load image: \(error.localizedDescription)")
                }
            }
        }

        updateUI()
    }
    
    private func updateUI() {
        let canGoPrevious = currentImageIndex > 0
        let canGoNext = currentImageIndex < images.count - 1
        
        delegate?.didChangeNavigationState(canGoNext: canGoNext, canGoPrevious: canGoPrevious)
        onNavigationStateChanged?(canGoNext, canGoPrevious)
        
        let pageInfo = "Image \(currentImageIndex + 1) of \(images.count)"
        delegate?.didUpdatePageInfo(pageInfo)
        onPageInfoUpdated?(pageInfo)
    }
} 
