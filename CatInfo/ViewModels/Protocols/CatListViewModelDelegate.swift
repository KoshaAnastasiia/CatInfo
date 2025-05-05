import Cocoa

protocol CatListViewModelDelegate: AnyObject, Sendable {
    func didSelectBreed(_ breed: CatBreed)
}
