import Cocoa
import RealmSwift

final class ImageCacheService: ImageCacheServiceProtocol {
    private let memoryCache = NSCache<NSString, NSImage>()
    private let realmQueue = DispatchQueue(label: "com.catinfo.realmQueue", qos: .background)
    
    private func getRealm() -> Realm {
        do {
            let config = Realm.Configuration(
                schemaVersion: 1,
                migrationBlock: { _, _ in },
                deleteRealmIfMigrationNeeded: true
            )
            return try Realm(configuration: config)
        } catch {
            fatalError("Failed to initialize Realm: \(error)")
        }
    }
    
    init() {
        memoryCache.countLimit = 100 // Maximum number of images to keep in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        setupCleanupTimer()
    }
    
    init(realmFactory: @escaping () -> Realm) {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        setupCleanupTimer()
    }
    
    // MARK: - ImageCacheServiceProtocol Implementation
    
    func getImage(forKey key: String) async -> NSImage? {
        // First try the memory cache (always safe on any thread)
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            // Update access time on background thread
            Task {
                await updateLastAccessedAsync(forKey: key)
            }
            return cachedImage
        }
        
        // If not in memory cache, load from disk asynchronously
        return await withCheckedContinuation { continuation in
            realmQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let imageData = self.getImageDataFromDisk(forKey: key)
                
                guard let data = imageData, let image = NSImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Store the loaded image in memory cache for faster access next time
                self.memoryCache.setObject(image, forKey: key as NSString)
                continuation.resume(returning: image)
            }
        }
    }
    
    func saveImage(_ image: NSImage, forKey key: String) {
        // Store in memory cache immediately (thread-safe)
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Convert to JPEG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }
        
        realmQueue.async { [weak self] in
            self?.saveImageDataToDisk(jpegData, forKey: key)
        }
    }
    
    func saveImageData(_ data: Data, forKey key: String) {
        // Try to create an image and store in memory cache (thread-safe)
        if let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
        }
        
        realmQueue.async { [weak self] in
            self?.saveImageDataToDisk(data, forKey: key)
        }
    }
    
    func clearCache() {
        // Clear memory cache immediately (thread-safe)
        memoryCache.removeAllObjects()
        
        // Clear disk cache on background thread
        realmQueue.async { [weak self] in
            guard let self = self else { return }
            
            let realm = self.getRealm()
            do {
                try realm.write {
                    realm.delete(realm.objects(CachedImage.self))
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
    // This methods must be called from the realmQueue
    
    private func getImageDataFromDisk(forKey key: String) -> Data? {
        let realm = getRealm()
        guard let cachedImage = realm.object(ofType: CachedImage.self, forPrimaryKey: key) else {
            return nil
        }
        
        updateLastAccessed(forKey: key)
        
        return cachedImage.data
    }
    
    private func updateLastAccessedAsync(forKey key: String) async {
        await withCheckedContinuation { continuation in
            realmQueue.async { [weak self] in
                self?.updateLastAccessed(forKey: key)
                continuation.resume()
            }
        }
    }
    
    private func saveImageDataToDisk(_ data: Data, forKey key: String) {
        let realm = getRealm()
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
        let realm = getRealm()
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
        // Schedule cleanup to run once a day
        let timer = Timer(timeInterval: 86400, repeats: true) { [weak self] _ in
            self?.cleanupOldEntries()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func cleanupOldEntries() {
        realmQueue.async { [weak self] in
            guard let self = self else { return }
            
            let realm = self.getRealm()
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
}
