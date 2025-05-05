import Cocoa

protocol RouterProtocol: AnyObject {
    var viewController: NSViewController? { get }
    
    func start()
    
    func showImageCarousel(for breedId: String)
    func dismissCurrentViewController()
} 
