import Cocoa

final class ServiceGraph: ServiceGraphProtocol {
    let apiService: CatAPIServiceProtocol
    let cacheService: ImageCacheServiceProtocol
    
    init() {
        self.cacheService = ImageCacheService()
        self.apiService = CatAPIService(cacheService: cacheService)
    }

    init(
        apiService: CatAPIServiceProtocol,
        cacheService: ImageCacheServiceProtocol
    ) {
        self.apiService = apiService
        self.cacheService = cacheService
    }
} 
