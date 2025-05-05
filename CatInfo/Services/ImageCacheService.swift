import Cocoa
import RealmSwift

final class ImageCacheService: ImageCacheServiceProtocol {
    private let memoryCache = NSCache<NSString, NSImage>()
    
    private lazy var realm: Realm = {
        let config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { _, _ in },
            deleteRealmIfMigrationNeeded: true
        )
        
        do {
            return try Realm(configuration: config)
        } catch {
            fatalError("Failed to initialize Realm: \(error)")
        }
    }()
    
    init() {
        memoryCache.countLimit = 100 // Maximum number of images to keep in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        setupCleanupTimer()
    }
    
    init(realm: Realm) {
        self.realm = realm
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        setupCleanupTimer()
    }
    
    // MARK: - ImageCacheServiceProtocol Implementation
    
    func getImage(forKey key: String) -> NSImage? {
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            DispatchQueue.main.async { [weak self] in
                self?.updateLastAccessed(forKey: key)
            }
            return cachedImage
        }
        
        var imageData: Data?
        
        if Thread.isMainThread {
            imageData = getImageDataFromDisk(forKey: key)
        } else {
            DispatchQueue.main.sync {
                imageData = self.getImageDataFromDisk(forKey: key)
            }
        }
        
        guard let data = imageData, let image = NSImage(data: data) else {
            return nil
        }
        
        memoryCache.setObject(image, forKey: key as NSString)
        return image
    }
    
    func saveImage(_ image: NSImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            
            DispatchQueue.main.async { [weak self] in
                self?.saveImageDataToDisk(jpegData, forKey: key)
            }
        }
    }
    
    func saveImageData(_ data: Data, forKey key: String) {
        if let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.saveImageDataToDisk(data, forKey: key)
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.realm.write {
                    self.realm.delete(self.realm.objects(CachedImage.self))
                }
            } catch {
                print("Failed to clear disk cache: \(error)")
            }
        }
    }
    
    static func makeCacheKey(from urlString: String) -> String {
        return urlString.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")
    }
    
    static func makeCacheKey(for breedImage: CatBreed.BreedImage) -> String? {
        guard let url = breedImage.url else { return nil }
        return makeCacheKey(from: url)
    }
    
    // MARK: - Private Methods
    
    private func getImageDataFromDisk(forKey key: String) -> Data? {
        assert(Thread.isMainThread, "Realm operations must be performed on the main thread")
        
        guard let cachedImage = realm.object(ofType: CachedImage.self, forPrimaryKey: key) else {
            return nil
        }
        
        updateLastAccessed(forKey: key)
        
        return cachedImage.data
    }
    
    private func saveImageDataToDisk(_ data: Data, forKey key: String) {
        assert(Thread.isMainThread, "Realm operations must be performed on the main thread")
        
        do {
            try realm.write {
                if let existingImage = realm.object(ofType: CachedImage.self, forPrimaryKey: key) {
                    existingImage.data = data
                    existingImage.lastAccessed = Date()
                } else {
                    let cachedImage = CachedImage(id: key, data: data)
                    realm.add(cachedImage, update: .modified)
                }
            }
        } catch {
            print("Failed to save image to disk: \(error)")
        }
    }
    
    private func updateLastAccessed(forKey key: String) {
        assert(Thread.isMainThread, "Realm operations must be performed on the main thread")
        
        do {
            try realm.write {
                if let cachedImage = realm.object(ofType: CachedImage.self, forPrimaryKey: key) {
                    cachedImage.lastAccessed = Date()
                }
            }
        } catch {
            print("Failed to update last accessed time: \(error)")
        }
    }
    
    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cleanupOldEntries()
            }
        }
    }
    
    private func cleanupOldEntries() {
        assert(Thread.isMainThread, "Realm operations must be performed on the main thread")
        
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        
        do {
            try realm.write {
                let oldImages = realm.objects(CachedImage.self).filter("lastAccessed < %@", oneMonthAgo)
                realm.delete(oldImages)
            }
        } catch {
            print("Failed to clean up old entries: \(error)")
        }
    }
} 
