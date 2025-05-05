import Cocoa

final class MainRouter: RouterProtocol {
    weak var viewController: NSViewController?
    private weak var presentedViewController: NSViewController?
    
    private let window: NSWindow
    private let serviceGraph: ServiceGraphProtocol
    
    init(
        window: NSWindow,
        serviceGraph: ServiceGraphProtocol
    ) {
        self.window = window
        self.serviceGraph = serviceGraph
    }
    
    func start() {
        let catListViewModel = CatListViewModel(
            apiService: serviceGraph.apiService
        )
        
        let catDetailViewModel = CatDetailViewModel(
            apiService: serviceGraph.apiService, 
            cacheService: serviceGraph.cacheService
        )
        
        let catViewController = CatViewController(
            catListViewModel: catListViewModel,
            catDetailViewModel: catDetailViewModel,
            router: self as RouterProtocol
        )
        
        self.viewController = catViewController
        window.contentViewController = catViewController
        window.makeKeyAndOrderFront(nil)
    }
    
    func showImageCarousel(for breedId: String) {
        let viewModel = ImageCarouselViewModel(
            breedId: breedId,
            apiService: serviceGraph.apiService,
            cacheService: serviceGraph.cacheService
        )
        
        let carouselVC = ImageCarouselViewController(
            viewModel: viewModel,
            router: self as RouterProtocol
        )
        
        viewController?.presentAsSheet(carouselVC)
        self.presentedViewController = carouselVC
        
        viewModel.loadImages()
    }
    
    func dismissCurrentViewController() {
        presentedViewController?.dismiss(nil)
        presentedViewController = nil
    }
} 
