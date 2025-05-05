import Cocoa

protocol CatDetailViewModelDelegate: AnyObject, Sendable {
    func didLoadImage(_ image: NSImage?)
    func didUpdateBreedDetails()
}
