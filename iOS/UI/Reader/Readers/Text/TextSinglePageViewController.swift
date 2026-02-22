//
//  TextSinglePageViewController.swift
//  Aidoku
//

import UIKit

class TextSinglePageViewController: UIViewController {
    let page: TextPage
    weak var parentReader: ReaderPagedTextViewController?

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .systemBackground
        tv.font = .systemFont(ofSize: 18)
        // Content padding (matches TextPaginator)
        tv.textContainerInset = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
        return tv
    }()

    // Dynamic constraints for safe area
    private var topConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    init(page: TextPage, parentReader: ReaderPagedTextViewController? = nil) {
        self.page = page
        self.parentReader = parentReader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        view.addSubview(textView)

        textView.translatesAutoresizingMaskIntoConstraints = false

        // Create constraints that we can update later
        topConstraint = textView.topAnchor.constraint(equalTo: view.topAnchor)
        leadingConstraint = textView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        trailingConstraint = textView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        bottomConstraint = textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([topConstraint!, leadingConstraint!, trailingConstraint!, bottomConstraint!])

        // Set the text content
        if page.attributedContent.length > 0 {
            textView.attributedText = page.attributedContent
        } else {
            textView.text = page.markdownContent
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Get safe area from parent reader (more reliable than child's safe area)
        let safeArea = parentReader?.view.safeAreaInsets ?? view.safeAreaInsets

        topConstraint?.constant = safeArea.top
        leadingConstraint?.constant = safeArea.left
        trailingConstraint?.constant = -safeArea.right
        bottomConstraint?.constant = -safeArea.bottom
    }
}
