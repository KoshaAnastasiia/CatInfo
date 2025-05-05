import Cocoa

protocol ServiceGraphProtocol {
    var apiService: CatAPIServiceProtocol { get }
    var cacheService: ImageCacheServiceProtocol { get }
}
