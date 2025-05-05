import Cocoa

class ImageCarouselViewController: NSViewController {
    
    // MARK: - View Model
    
    private let viewModel: ImageCarouselViewModel
    private weak var router: RouterProtocol?
    
    // MARK: - UI Components
    
    private lazy var containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()
    
    private lazy var imageView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }()
    
    private lazy var previousButton: NSButton = {
        let button = NSButton(title: "◀", target: self, action: #selector(showPreviousImage))
        button.bezelStyle = .rounded
        button.isEnabled = false
        return button
    }()
    
    private lazy var nextButton: NSButton = {
        let button = NSButton(title: "▶", target: self, action: #selector(showNextImage))
        button.bezelStyle = .rounded
        button.isEnabled = false
        return button
    }()
    
    private lazy var closeButton: NSButton = {
        let button = NSButton(title: "Close", target: self, action: #selector(close))
        button.bezelStyle = .rounded
        return button
    }()
    
    private lazy var pageInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Image 0 of 0")
        label.font = NSFont.systemFont(ofSize: 12)
        return label
    }()
    
    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .large
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    private lazy var imageLoadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    // MARK: - Initializers
    
    init(viewModel: ImageCarouselViewModel, router: RouterProtocol) {
        self.viewModel = viewModel
        self.router = router
        super.init(nibName: nil, bundle: nil)
        self.viewModel.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupBindings()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        containerView.addSubview(imageView)
        containerView.addSubview(imageLoadingIndicator)
        
        let controlsStackView = NSStackView(views: [previousButton, pageInfoLabel, nextButton])
        controlsStackView.spacing = 10
        controlsStackView.distribution = .gravityAreas
        
        containerView.addSubview(controlsStackView)
        containerView.addSubview(closeButton)
        containerView.addSubview(loadingIndicator)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.8),
            
            imageLoadingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            imageLoadingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            controlsStackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 15),
            controlsStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            closeButton.topAnchor.constraint(equalTo: controlsStackView.bottomAnchor, constant: 20),
            closeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            closeButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    private func setupBindings() {
        loadingIndicator.startAnimation(nil)
    }
    
    // MARK: - User Actions
    
    @objc private func showPreviousImage() {
        viewModel.showPreviousImage()
    }
    
    @objc private func showNextImage() {
        viewModel.showNextImage()
    }
    
    @objc private func close() {
        router?.dismissCurrentViewController()
    }
}

// MARK: - ImageCarouselViewModelDelegate

extension ImageCarouselViewController: ImageCarouselViewModelDelegate {
    func didUpdateCurrentImage(_ image: NSImage?) {
        imageView.image = image
        imageLoadingIndicator.stopAnimation(nil)
    }
    
    func didUpdatePageInfo(_ info: String) {
        pageInfoLabel.stringValue = info
    }
    
    func didChangeNavigationState(canGoNext: Bool, canGoPrevious: Bool) {
        previousButton.isEnabled = canGoPrevious
        nextButton.isEnabled = canGoNext
    }
    
    func didFinishLoading() {
        loadingIndicator.stopAnimation(nil)
    }
    
    func didEncounterError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
} 
