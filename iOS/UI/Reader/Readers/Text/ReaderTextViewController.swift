//
//  ReaderTextViewController.swift
//  Aidoku
//
//  Created by Skitty on 5/13/25.
//

import AidokuRunner
import SwiftUI
import ZIPFoundation

class ReaderTextViewController: BaseViewController {
    let viewModel: ReaderTextViewModel

    var readingMode: ReadingMode = .rtl
    var delegate: (any ReaderHoldingDelegate)?

    // Chapter navigation
    private var chapter: AidokuRunner.Chapter?
    private var previousChapter: AidokuRunner.Chapter?
    private var nextChapter: AidokuRunner.Chapter?
    private var isLoadingChapter = false
    private var hasReachedEnd = false

    private var isSliding = false
    private var estimatedPageCount = 1
    private var pendingScrollRestore = false
    private var isReportingProgress = false
    private var lastReportedPage = 0
    private var needsPageCountUpdate = false

    // MARK: - Scroll Position Persistence

    /// Save reading progress (0.0–1.0) for the current chapter.
    /// Uses a shared key so both scroll and paged readers stay in sync.
    private func saveReadingProgress(_ progress: CGFloat) {
        guard let chapterKey = chapter?.key else { return }
        UserDefaults.standard.set(Double(progress), forKey: "TextReader.progress.\(chapterKey)")
    }

    /// Load previously saved reading progress for a chapter. Returns nil if none stored.
    private func loadReadingProgress(for chapterKey: String) -> CGFloat? {
        let value = UserDefaults.standard.object(forKey: "TextReader.progress.\(chapterKey)")
        return (value as? Double).map { CGFloat($0) }
    }

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .systemBackground
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()

    private lazy var contentStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        return sv
    }()

    private var hostingController: UIHostingController<ReaderTextView>?

    private func createHostingController(page: Page?) -> UIHostingController<ReaderTextView> {
        let hc = HostingController(
            rootView: ReaderTextView(source: viewModel.source, page: page)
        )
        if #available(iOS 16.0, *) {
            hc.sizingOptions = .intrinsicContentSize
        }
        hc.view.backgroundColor = .clear
        return hc
    }

    // Footer view for chapter navigation
    private lazy var footerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    private lazy var footerStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 16
        return sv
    }()

    private lazy var footerTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var footerChapterLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var nextChapterButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = NSLocalizedString("CONTINUE_READING")
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(nextChapterTapped), for: .touchUpInside)
        return button
    }()

    init(source: AidokuRunner.Source?, manga: AidokuRunner.Manga) {
        self.viewModel = .init(source: source, manga: manga)
        super.init()
    }

    override func configure() {
        // Create initial hosting controller
        let hc = createHostingController(page: viewModel.pages.first)
        hostingController = hc
        addChild(hc)
        hc.didMove(toParent: self)

        // Build content stack
        contentStackView.addArrangedSubview(hc.view)
        contentStackView.addArrangedSubview(footerView)

        // Footer content
        footerView.addSubview(footerStackView)
        footerStackView.addArrangedSubview(footerTitleLabel)
        footerStackView.addArrangedSubview(footerChapterLabel)
        footerStackView.addArrangedSubview(nextChapterButton)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        // Initially hide footer
        footerView.isHidden = true
    }

    override func constrain() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        hostingController?.view.translatesAutoresizingMaskIntoConstraints = false
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            // Fix the width to prevent horizontal scrolling
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            // Footer layout
            footerView.heightAnchor.constraint(equalToConstant: 200),
            footerStackView.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            footerStackView.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            footerStackView.leadingAnchor.constraint(greaterThanOrEqualTo: footerView.leadingAnchor, constant: 32),
            footerStackView.trailingAnchor.constraint(lessThanOrEqualTo: footerView.trailingAnchor, constant: -32)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        hostingController?.view.invalidateIntrinsicContentSize()

        // One-shot page count update after content is laid out
        if needsPageCountUpdate {
            let contentHeight = scrollView.contentSize.height
            let screenHeight = scrollView.frame.size.height
            if contentHeight > screenHeight, screenHeight > 0 {
                needsPageCountUpdate = false
                let newCount = max(1, Int(ceil(contentHeight / screenHeight)))
                if newCount != estimatedPageCount, let firstPage = viewModel.pages.first {
                    estimatedPageCount = newCount
                    // Report virtual page count to toolbar
                    let virtualPages = Array(repeating: firstPage, count: estimatedPageCount)
                    delegate?.setPages(virtualPages)
                }
            }
        }
    }

    private func updateFooter() {
        if let nextChapter {
            footerView.isHidden = false
            footerTitleLabel.text = NSLocalizedString("NEXT_CHAPTER")

            if let chapterNum = nextChapter.chapterNumber {
                footerChapterLabel.text = String(format: NSLocalizedString("CHAPTER_X", comment: ""), chapterNum)
            } else {
                footerChapterLabel.text = nextChapter.title ?? ""
            }

            nextChapterButton.isHidden = false
        } else {
            footerView.isHidden = false
            footerTitleLabel.text = NSLocalizedString("NO_NEXT_CHAPTER")
            footerChapterLabel.text = NSLocalizedString("END_OF_MANGA")
            nextChapterButton.isHidden = true
        }
    }

    @objc private func nextChapterTapped() {
        loadNextChapter()
    }

    func loadNextChapter() {
        guard let nextChapter, !isLoadingChapter else { return }
        delegate?.setChapter(nextChapter)
        Task {
            await loadChapter(nextChapter)
        }
    }

    func loadPreviousChapter() {
        guard let previousChapter, !isLoadingChapter else { return }
        delegate?.setChapter(previousChapter)
        Task {
            await loadChapter(previousChapter)
        }
    }

    private func loadChapter(_ chapter: AidokuRunner.Chapter, restorePosition: Bool = true) async {
        isLoadingChapter = true
        hasReachedEnd = false
        self.chapter = chapter

        await viewModel.loadPages(chapter: chapter)
        delegate?.setPages(viewModel.pages)

        await MainActor.run {
            previousChapter = delegate?.getPreviousChapter()
            nextChapter = delegate?.getNextChapter()

            // Update text - recreate hosting controller to force full refresh
            if let firstPage = viewModel.pages.first {
                // Remove old view
                hostingController?.view.removeFromSuperview()
                hostingController?.removeFromParent()

                // Create new hosting controller with new content
                let newHostingController = createHostingController(page: firstPage)

                // Add to view hierarchy
                addChild(newHostingController)
                newHostingController.didMove(toParent: self)

                // Insert at the beginning of the stack view
                contentStackView.insertArrangedSubview(newHostingController.view, at: 0)
                newHostingController.view.translatesAutoresizingMaskIntoConstraints = false

                // Update reference
                hostingController = newHostingController
            }

            // Update footer
            updateFooter()

            // Force scroll view to recalculate content size
            view.layoutIfNeeded()

            // Flag for page count calculation once content is laid out
            needsPageCountUpdate = true

            // Restore saved scroll position or scroll to top
            if restorePosition, let savedProgress = loadReadingProgress(for: chapter.key) {
                pendingScrollRestore = true
                // Defer scroll restore until content is fully laid out
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let contentHeight = self.scrollView.contentSize.height
                    let screenHeight = self.scrollView.frame.size.height
                    let totalHeight = contentHeight - screenHeight
                    if totalHeight > 0 {
                        // Calculate page count now (before restore) so toolbar is correct
                        if screenHeight > 0 {
                            let newCount = max(1, Int(ceil(contentHeight / screenHeight)))
                            if newCount != self.estimatedPageCount, let firstPage = self.viewModel.pages.first {
                                self.estimatedPageCount = newCount
                                self.needsPageCountUpdate = false
                                let virtualPages = Array(repeating: firstPage, count: newCount)
                                self.delegate?.setPages(virtualPages)
                            }
                        }

                        let targetOffset = totalHeight * savedProgress
                        self.scrollView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
                        let currentPage = min(self.estimatedPageCount, Int(savedProgress * CGFloat(self.estimatedPageCount)) + 1)
                        self.lastReportedPage = currentPage
                        self.delegate?.setCurrentPage(currentPage)
                    }
                    self.pendingScrollRestore = false
                }
            } else {
                scrollView.setContentOffset(.init(x: 0, y: 0), animated: false)
            }

            isLoadingChapter = false
        }
    }
}

// MARK: - Reader Delegate
extension ReaderTextViewController: ReaderReaderDelegate {
    func moveLeft() {
        // At the top? Try previous chapter
        if scrollView.contentOffset.y <= 0 {
            loadPreviousChapter()
            return
        }

        let offset = CGPoint(
            x: scrollView.contentOffset.x,
            y: max(
                0,
                scrollView.contentOffset.y - scrollView.bounds.height * 2/3
            )
        )
        scrollView.setContentOffset(
            offset,
            animated: UserDefaults.standard.bool(forKey: "Reader.animatePageTransitions")
        )
    }

    func moveRight() {
        let maxOffset = scrollView.contentSize.height - scrollView.bounds.height

        // At the bottom? Try next chapter
        if scrollView.contentOffset.y >= maxOffset - 10 {
            loadNextChapter()
            return
        }

        let offset = CGPoint(
            x: scrollView.contentOffset.x,
            y: min(
                maxOffset,
                scrollView.contentOffset.y + scrollView.bounds.height * 2/3
            )
        )
        scrollView.setContentOffset(
            offset,
            animated: UserDefaults.standard.bool(forKey: "Reader.animatePageTransitions")
        )
    }

    func sliderMoved(value: CGFloat) {
        isSliding = true

        let totalHeight = scrollView.contentSize.height - scrollView.frame.size.height
        guard totalHeight > 0 else { return }
        let offset = totalHeight * value

        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: offset),
            animated: false
        )

        // Show current page while sliding
        let page = max(1, min(Int(value * CGFloat(estimatedPageCount - 1)) + 1, estimatedPageCount))
        delegate?.displayPage(page)
    }

    func sliderStopped(value: CGFloat) {
        isSliding = false

        // Commit current page
        let totalHeight = scrollView.contentSize.height - scrollView.frame.size.height
        guard totalHeight > 0 else { return }
        let progress = min(1, max(0, scrollView.contentOffset.y / totalHeight))
        let page = min(estimatedPageCount, Int(progress * CGFloat(estimatedPageCount)) + 1)
        delegate?.setCurrentPage(page)
    }

    func setChapter(_ chapter: AidokuRunner.Chapter, startPage: Int) {
        guard chapter != viewModel.chapter else { return }

        Task {
            await loadChapter(chapter, restorePosition: startPage > 0)
        }
    }
}

// MARK: - Scroll View Delegate
extension ReaderTextViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSliding, !pendingScrollRestore, !isReportingProgress else { return }

        let totalHeight = scrollView.contentSize.height - scrollView.frame.size.height
        guard totalHeight > 0 else { return }

        let progress = min(1, max(0, scrollView.contentOffset.y / totalHeight))

        let currentPage: Int
        let screenHeight = scrollView.frame.size.height
        if screenHeight > 0 {
            currentPage = min(estimatedPageCount, Int(progress * CGFloat(estimatedPageCount)) + 1)
        } else {
            currentPage = 1
        }

        // Only update delegate when page actually changed
        isReportingProgress = true
        if currentPage != lastReportedPage {
            lastReportedPage = currentPage
            delegate?.setCurrentPage(currentPage)
        }
        isReportingProgress = false

        // Save scroll progress periodically
        saveReadingProgress(progress)

        // Mark as completed when reaching the end (within 50pt of bottom)
        if scrollView.contentOffset.y >= totalHeight - 50 && !hasReachedEnd {
            hasReachedEnd = true
            delegate?.setCurrentPage(currentPage)
            delegate?.setCompleted()
        }
    }
}

// MARK: - ReaderTextView
private struct ReaderTextView: View {
    let source: AidokuRunner.Source?
    let text: String?

    private var fontFamily: String {
        UserDefaults.standard.string(forKey: "Reader.textFontFamily") ?? "System"
    }
    private var fontSize: Double {
        UserDefaults.standard.object(forKey: "Reader.textFontSize") as? Double ?? 18
    }
    private var lineSpacing: Double {
        UserDefaults.standard.object(forKey: "Reader.textLineSpacing") as? Double ?? 8
    }

    init(source: AidokuRunner.Source?, page: Page?) {
        self.source = source

        func loadText(page: Page) -> String? {
            if let text = page.text {
                return text
            }

            guard
                let zipURL = page.zipURL.flatMap({ URL(string: $0) }),
                let filePath = page.imageURL
            else {
                return nil
            }
            do {
                var data = Data()
                let archive = try Archive(url: zipURL, accessMode: .read)
                guard let entry = archive[filePath] else {
                    return nil
                }
                _ = try archive.extract(
                    entry,
                    consumer: { readData in
                        data.append(readData)
                    }
                )
                return String(data: data, encoding: .utf8)
            } catch {
                return nil
            }
        }
        self.text = page.flatMap { loadText(page: $0) }
    }

    var body: some View {
        if let text {
            MarkdownView(text, fontFamily: fontFamily, fontSize: fontSize, lineSpacing: lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
