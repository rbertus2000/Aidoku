//
//  TextSinglePageViewController.swift
//  Aidoku

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

        // Use safe area for proper positioning under status bar and above home indicator
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Set the text content
        if page.attributedContent.length > 0 {
            textView.attributedText = page.attributedContent
        } else {
            textView.text = page.markdownContent
        }
    }
}
