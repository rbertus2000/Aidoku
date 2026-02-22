//
//  ChapterTransitionViewController.swift
//  Aidoku
//

import AidokuRunner
import UIKit

class ChapterTransitionViewController: UIViewController {
    enum Direction {
        case next
        case previous
    }

    let direction: Direction
    let chapter: AidokuRunner.Chapter?
    weak var parentReader: ReaderPagedTextViewController?

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 16
        return sv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var chapterLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        return label
    }()

    init(direction: Direction, chapter: AidokuRunner.Chapter?, parentReader: ReaderPagedTextViewController?) {
        self.direction = direction
        self.chapter = chapter
        self.parentReader = parentReader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(chapterLabel)
        stackView.addArrangedSubview(instructionLabel)

        if let chapter {
            titleLabel.text = direction == .next
                ? NSLocalizedString("NEXT_CHAPTER")
                : NSLocalizedString("PREVIOUS_CHAPTER")

            if let chapterNum = chapter.chapterNumber {
                chapterLabel.text = String(format: NSLocalizedString("CHAPTER_X", comment: ""), chapterNum)
            } else {
                chapterLabel.text = chapter.title ?? ""
            }

            instructionLabel.text = direction == .next
                ? NSLocalizedString("SWIPE_TO_CONTINUE")
                : NSLocalizedString("SWIPE_TO_GO_BACK")
        } else {
            titleLabel.text = direction == .next
                ? NSLocalizedString("NO_NEXT_CHAPTER")
                : NSLocalizedString("NO_PREVIOUS_CHAPTER")
            chapterLabel.text = direction == .next
                ? NSLocalizedString("END_OF_MANGA")
                : NSLocalizedString("START_OF_MANGA")
            instructionLabel.isHidden = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Load the chapter when this view appears (user swiped to it)
        if chapter != nil {
            if direction == .next {
                parentReader?.loadNextChapter()
            } else {
                parentReader?.loadPreviousChapter()
            }
        }
    }
}
