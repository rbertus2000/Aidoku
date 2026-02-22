//
//  TextDoublePageViewController.swift
//  Aidoku
//

import UIKit

class TextDoublePageViewController: UIViewController {
    enum Direction {
        case ltr
        case rtl
    }

    let leftPage: TextPage
    let rightPage: TextPage
    let direction: Direction
    weak var parentReader: ReaderPagedTextViewController?

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 1
        return sv
    }()

    private lazy var leftTextView: UITextView = createTextView()
    private lazy var rightTextView: UITextView = createTextView()
    private lazy var dividerView: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        return v
    }()

    // Dynamic constraints for safe area
    private var topConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    init(leftPage: TextPage, rightPage: TextPage, direction: Direction, parentReader: ReaderPagedTextViewController? = nil) {
        self.leftPage = leftPage
        self.rightPage = rightPage
        self.direction = direction
        self.parentReader = parentReader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        view.addSubview(dividerView)
        dividerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if direction == .rtl {
            stackView.addArrangedSubview(rightTextView)
            stackView.addArrangedSubview(leftTextView)
            rightTextView.attributedText = rightPage.attributedContent
            leftTextView.attributedText = leftPage.attributedContent
        } else {
            stackView.addArrangedSubview(leftTextView)
            stackView.addArrangedSubview(rightTextView)
            leftTextView.attributedText = leftPage.attributedContent
            rightTextView.attributedText = rightPage.attributedContent
        }

        // Create dynamic constraints
        topConstraint = stackView.topAnchor.constraint(equalTo: view.topAnchor)
        leadingConstraint = stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        trailingConstraint = stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        bottomConstraint = stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            topConstraint!, leadingConstraint!, trailingConstraint!, bottomConstraint!,
            dividerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dividerView.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 20),
            dividerView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: -20),
            dividerView.widthAnchor.constraint(equalToConstant: 1)
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let safeArea = parentReader?.view.safeAreaInsets ?? view.safeAreaInsets

        topConstraint?.constant = safeArea.top
        leadingConstraint?.constant = safeArea.left
        trailingConstraint?.constant = -safeArea.right
        bottomConstraint?.constant = -safeArea.bottom
    }

    private func createTextView() -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .systemBackground
        // Must match TextPaginator's padding: horizontalPadding=24, verticalPadding=32
        tv.textContainerInset = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
        return tv
    }
}
