import Cocoa

final class CatListViewModel: Sendable {
    private let apiService: CatAPIServiceProtocol
    private(set) var breeds: [CatBreed] = []
    private(set) var isLoading = false
    
    weak var delegate: CatListViewModelDelegate?
    
    var hasBreeds: Bool {
        return !breeds.isEmpty
    }
    
    var onBreedsLoaded: (() -> Void)?
    var onError: ((String) -> Void)?
    var onLoadingStateChanged: ((Bool) -> Void)?
    
    init(apiService: CatAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func fetchBreeds() {
        guard !isLoading else { return }
        
        isLoading = true
        onLoadingStateChanged?(true)
        
        Task {
            do {
                let fetchedBreeds = try await apiService.fetchBreeds()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.breeds = fetchedBreeds
                    self.isLoading = false
                    self.onLoadingStateChanged?(false)
                    self.onBreedsLoaded?()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.onLoadingStateChanged?(false)
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }
    
    func selectBreed(at index: Int) {
        guard index >= 0 && index < breeds.count else { return }
        
        let selectedBreed = breeds[index]
        delegate?.didSelectBreed(selectedBreed)
    }
    
    func numberOfBreeds() -> Int {
        return breeds.count
    }
    
    func breedName(at index: Int) -> String {
        guard index >= 0 && index < breeds.count else { return "" }
        return breeds[index].name
    }
} 
