import Cocoa

class CatViewController: NSViewController, NSSplitViewDelegate {
    
    // MARK: - View Models
    
    private let catListViewModel: CatListViewModel
    private let catDetailViewModel: CatDetailViewModel
    private weak var router: RouterProtocol?
    
    // MARK: - Constraint
    private var detailScrollViewLeading: NSLayoutConstraint?
    private var detailScrollViewTrailing: NSLayoutConstraint?
    private var detailScrollViewMaxWidth: CGFloat = .infinity

    // MARK: - UI Components
    
    private lazy var splitView: NSSplitView = {
        let view = NSSplitView()
        view.isVertical = true
        view.dividerStyle = .thin
        view.delegate = self
        return view
    }()
    
    private lazy var breedsTableView: NSTableView = {
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("BreedName"))
        column.title = "Breed"
        column.width = 200
        tableView.addTableColumn(column)
        
        return tableView
    }()
    
    private lazy var breedsScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.documentView = breedsTableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }()
    
    private lazy var detailView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()
    
    private lazy var detailScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.documentView = detailStackView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }()
    
    private lazy var detailStackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 15
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var breedImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 300),
            imageView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        let clickGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(imageViewClicked)
        )
        imageView.addGestureRecognizer(clickGesture)
        imageView.isEnabled = true
        
        return imageView
    }()
    
    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    private lazy var breedNameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 24)
        return label
    }()
    
    private lazy var originLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var temperamentLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var descriptionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14)
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 400
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var weightLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var lifeSpanLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var wikipediaButton: NSButton = {
        let button = NSButton(
            title: "Visit Wikipedia",
            target: self,
            action: #selector(openWikipedia)
        )
        button.bezelStyle = .rounded
        button.isHidden = true
        return button
    }()
    
    // MARK: - Initializers
    
    init(
        catListViewModel: CatListViewModel,
        catDetailViewModel: CatDetailViewModel,
        router: RouterProtocol
    ) {
        self.catListViewModel = catListViewModel
        self.catDetailViewModel = catDetailViewModel
        self.router = router
        super.init(nibName: nil, bundle: nil)
        
        self.catListViewModel.delegate = self
        self.catDetailViewModel.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        self.view = NSView(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 700)
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupBindings()
        
        catListViewModel.fetchBreeds()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let targetWidth = max(250, view.frame.width * 0.25)
        splitView.setPosition(targetWidth, ofDividerAt: 0)
    }
    
    override func viewWillLayout() {
        super.viewWillLayout()
        let margin = view.bounds.width - detailScrollViewMaxWidth
        
        if margin > 0 {
            detailScrollViewLeading?.constant = margin
            detailScrollViewTrailing?.constant = -margin
        } else {
            detailScrollViewLeading?.constant = 0
            detailScrollViewTrailing?.constant = 0
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupSplitView()
        setupDetailView()
    }
    
    private func setupSplitView() {
        view.addSubview(splitView)
        
        splitView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        splitView.addArrangedSubview(breedsScrollView)
        splitView.addArrangedSubview(detailView)
    }
    
    private func setupDetailView() {
        detailView.addSubview(detailScrollView)
        
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        detailScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        detailScrollViewLeading = detailScrollView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor)
        detailScrollViewTrailing = detailScrollView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor)
        
        detailScrollViewLeading?.isActive = true
        detailScrollViewTrailing?.isActive = true
        
        let imageContainer = NSView()
        imageContainer.addSubview(breedImageView)
        imageContainer.addSubview(loadingIndicator)
        
        breedImageView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            breedImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            breedImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            breedImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            breedImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor)
        ])
        
        // Add all elements to stack view
        detailStackView.addArrangedSubview(imageContainer)
        detailStackView.addArrangedSubview(breedNameLabel)
        detailStackView.addArrangedSubview(originLabel)
        detailStackView.addArrangedSubview(temperamentLabel)
        detailStackView.addArrangedSubview(descriptionLabel)
        detailStackView.addArrangedSubview(weightLabel)
        detailStackView.addArrangedSubview(lifeSpanLabel)
        detailStackView.addArrangedSubview(wikipediaButton)
        
        // Add spacing between items
        detailStackView.setCustomSpacing(20, after: imageContainer)
        detailStackView.setCustomSpacing(15, after: breedNameLabel)
        detailStackView.setCustomSpacing(20, after: descriptionLabel)
    }
    
    private func setupBindings() {
        // List view model callbacks
        catListViewModel.onBreedsLoaded = { [weak self] in
            self?.breedsTableView.reloadData()
            
            if self?.catListViewModel.hasBreeds == true {
                self?.breedsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self?.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
            }
        }
        
        catListViewModel.onError = { [weak self] errorMessage in
            self?.showError(errorMessage)
        }
        
        catDetailViewModel.onImageLoaded = { [weak self] image in
            self?.breedImageView.image = image
            self?.loadingIndicator.stopAnimation(nil)
        }
        
        catDetailViewModel.onBreedDetailsUpdated = { [weak self] in
            self?.updateDetailView()
        }
        
        catDetailViewModel.onError = { [weak self] errorMessage in
            self?.showError(errorMessage)
        }
    }
    
    // MARK: - UI Updates
    
    private func updateDetailView() {
        breedNameLabel.stringValue = catDetailViewModel.name
        originLabel.stringValue = catDetailViewModel.origin
        temperamentLabel.stringValue = catDetailViewModel.temperament
        descriptionLabel.stringValue = catDetailViewModel.descriptionText
        weightLabel.stringValue = catDetailViewModel.weight
        lifeSpanLabel.stringValue = catDetailViewModel.lifeSpan
        
        wikipediaButton.isHidden = !catDetailViewModel.hasWikipediaLink
        
        loadingIndicator.startAnimation(nil)
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Actions
    
    @objc private func imageViewClicked() {
        guard let breedId = catDetailViewModel.breedId else { return }
        router?.showImageCarousel(for: breedId)
    }
    
    @objc private func openWikipedia() {
        catDetailViewModel.openWikipedia()
    }
    
    // MARK: - NSSplitViewDelegate
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 200  // Minimum width for the breeds list
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.frame.width * 0.4  // Maximum width for the breeds list - 40% of total width
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension CatViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return catListViewModel.numberOfBreeds()
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("BreedCell")
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier
            
            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }
        
        cellView?.textField?.stringValue = catListViewModel.breedName(at: row)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = breedsTableView.selectedRow
        if selectedRow >= 0 {
            catListViewModel.selectBreed(at: selectedRow)
        }
    }
}

// MARK: - CatListViewModelDelegate
extension CatViewController: CatListViewModelDelegate {
    func didSelectBreed(_ breed: CatBreed) {
        catDetailViewModel.setBreed(breed)
    }
}

// MARK: - CatDetailViewModelDelegate
extension CatViewController: CatDetailViewModelDelegate {
    func didLoadImage(_ image: NSImage?) {
        breedImageView.image = image
        loadingIndicator.stopAnimation(nil)
    }
    
    func didUpdateBreedDetails() {
        updateDetailView()
    }
} 
