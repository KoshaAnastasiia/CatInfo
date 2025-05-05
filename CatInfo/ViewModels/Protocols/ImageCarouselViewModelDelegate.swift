import Cocoa

protocol ImageCarouselViewModelDelegate: AnyObject {
    func didUpdateCurrentImage(_ image: NSImage?)
    func didUpdatePageInfo(_ info: String)
    func didChangeNavigationState(canGoNext: Bool, canGoPrevious: Bool)
    func didFinishLoading()
    func didEncounterError(_ message: String)
}
