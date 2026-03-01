//
//  TextPaginator.swift
//  Aidoku
//
//  Core pagination engine for breaking markdown text into discrete pages.
//  Calculates how much text fits on each page based on available space,
//  font settings, and line spacing.
//

import UIKit

/// Represents a single page of paginated text
struct TextPage: Identifiable, Equatable {
    let id: Int
    let attributedContent: NSAttributedString
    let markdownContent: String
    let range: NSRange  // Range in original text

    static func == (lhs: TextPage, rhs: TextPage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Configuration for text pagination
struct PaginationConfig {
    var fontSize: CGFloat = 16
    var fontName: String = "System"
    var lineSpacing: CGFloat = 6
    var paragraphSpacing: CGFloat = 12
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 32

    var font: UIFont {
        if fontName == "San Francisco" || fontName == "System" {
            return UIFont.systemFont(ofSize: fontSize)
        }
        return UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
    }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        return style
    }

    var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.label
        ]
    }
}

/// Main pagination engine
class TextPaginator {
    private var config: PaginationConfig
    private var pageSize: CGSize = .zero

    init(config: PaginationConfig = PaginationConfig()) {
        self.config = config
    }

    /// Update pagination configuration
    func updateConfig(_ config: PaginationConfig) {
        self.config = config
    }

    /// Calculate the usable content area for a page
    func contentSize(for pageSize: CGSize) -> CGSize {
        CGSize(
            width: pageSize.width - (config.horizontalPadding * 2),
            height: pageSize.height - (config.verticalPadding * 2)
        )
    }

    /// Paginate markdown text into discrete pages
    /// - Parameters:
    ///   - markdown: The source markdown text
    ///   - pageSize: The available page size (full screen)
    /// - Returns: Array of TextPage objects
    func paginate(markdown: String, pageSize: CGSize) -> [TextPage] {
        self.pageSize = pageSize

        // Convert markdown to attributed string
        let attributedString = markdownToAttributedString(markdown)

        // Calculate content area
        let contentArea = contentSize(for: pageSize)

        // Paginate the attributed string
        return paginateAttributedString(attributedString, contentSize: contentArea, originalMarkdown: markdown)
    }

    /// Convert markdown to NSAttributedString with proper styling.
    /// Handles headers, bold, italic, and preserves paragraph structure.
    ///
    /// Follows standard Markdown newline rules:
    /// - A single newline is treated as a soft break (space) — text flows together.
    /// - A blank line (two consecutive newlines) starts a new paragraph.
    /// - A line ending with two or more trailing spaces is a hard line break.
    private func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Split into paragraphs on blank lines (two+ consecutive newlines)
        let paragraphs = markdown.components(separatedBy: "\n\n")

        for (pIndex, paragraph) in paragraphs.enumerated() {
            let lines = paragraph.components(separatedBy: "\n")

            for (lIndex, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                // Skip empty lines within a paragraph block
                guard !trimmedLine.isEmpty else { continue }

                // Check for headers
                var headerLevel = 0
                var headerText = line
                if trimmedLine.hasPrefix("######") {
                    headerLevel = 6
                    headerText = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("#####") {
                    headerLevel = 5
                    headerText = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("####") {
                    headerLevel = 4
                    headerText = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("###") {
                    headerLevel = 3
                    headerText = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("##") {
                    headerLevel = 2
                    headerText = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                } else if trimmedLine.hasPrefix("#") {
                    headerLevel = 1
                    headerText = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                }

                if headerLevel > 0 {
                    // Headers always get their own block
                    if result.length > 0 {
                        result.append(NSAttributedString(string: "\n", attributes: config.attributes))
                    }
                    result.append(createHeaderAttributedString(headerText, level: headerLevel))
                    // Ensure a newline after the header so subsequent text starts on a new line
                    result.append(NSAttributedString(string: "\n", attributes: config.attributes))
                } else {
                    // Regular text line
                    let hasHardBreak = line.hasSuffix("  ") // two+ trailing spaces = hard break

                    // Join with previous line in the same paragraph using a space (soft break)
                    if lIndex > 0 && result.length > 0 {
                        // Check if the previous content ended with a hard break newline
                        let lastChar = result.string.last
                        if lastChar != "\n" {
                            result.append(NSAttributedString(string: " ", attributes: config.attributes))
                        }
                    }

                    let lineText = hasHardBreak ? String(line.dropLast(2)) : line
                    result.append(parseInlineMarkdown(lineText))

                    // If the line had trailing spaces, insert a hard line break
                    if hasHardBreak {
                        result.append(NSAttributedString(string: "\n", attributes: config.attributes))
                    }
                }
            }

            // Add paragraph separator between paragraphs (except after the last one)
            if pIndex < paragraphs.count - 1 {
                // Avoid double newlines if the paragraph ended with a header or hard break
                let endsWithNewline = result.string.hasSuffix("\n")
                if !endsWithNewline {
                    result.append(NSAttributedString(string: "\n", attributes: config.attributes))
                }
            }
        }

        return result
    }

    /// Create an attributed string for a header
    private func createHeaderAttributedString(_ text: String, level: Int) -> NSAttributedString {
        // Scale font size based on header level
        let sizeMultiplier: CGFloat = switch level {
            case 1: 1.75
            case 2: 1.5
            case 3: 1.25
            case 4: 1.15
            case 5: 1.1
            default: 1.05
        }

        let headerFontSize = config.fontSize * sizeMultiplier
        var headerFont: UIFont
        if config.fontName == "San Francisco" || config.fontName == "System" {
            headerFont = UIFont.systemFont(ofSize: headerFontSize, weight: .bold)
        } else {
            headerFont = UIFont(name: config.fontName, size: headerFontSize) ?? UIFont.systemFont(ofSize: headerFontSize)
            // Apply bold trait
            if let boldDescriptor = headerFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                headerFont = UIFont(descriptor: boldDescriptor, size: headerFontSize)
            }
        }

        // Header paragraph style with extra spacing
        let headerParagraphStyle = NSMutableParagraphStyle()
        headerParagraphStyle.lineSpacing = config.lineSpacing
        headerParagraphStyle.paragraphSpacingBefore = config.paragraphSpacing
        headerParagraphStyle.paragraphSpacing = config.paragraphSpacing / 2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .paragraphStyle: headerParagraphStyle,
            .foregroundColor: UIColor.label
        ]

        // Parse inline markdown within the header text
        let inlineAttributed = parseInlineMarkdown(text)
        let mutable = NSMutableAttributedString(attributedString: inlineAttributed)
        mutable.addAttributes(attributes, range: NSRange(location: 0, length: mutable.length))

        return mutable
    }

    /// Parse inline markdown (bold, italic) within a line
    private func parseInlineMarkdown(_ text: String) -> NSAttributedString {
        // Try Apple's built-in markdown parser for inline elements
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let mutable = NSMutableAttributedString(attributed)
            let fullRange = NSRange(location: 0, length: mutable.length)

            // Apply base styling
            mutable.addAttributes(config.attributes, range: fullRange)

            // Re-apply bold/italic from the markdown parse
            mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                guard let existingFont = value as? UIFont else { return }
                let traits = existingFont.fontDescriptor.symbolicTraits
                var newFont = config.font
                if traits.contains(.traitBold),
                   let boldDescriptor = newFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                    newFont = UIFont(descriptor: boldDescriptor, size: newFont.pointSize)
                }
                if traits.contains(.traitItalic),
                   let italicDescriptor = newFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                    newFont = UIFont(descriptor: italicDescriptor, size: newFont.pointSize)
                }
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            return mutable
        }

        // Fallback: plain text
        return NSAttributedString(string: text, attributes: config.attributes)
    }

    /// Split attributed string into pages based on available height
    private func paginateAttributedString(
        _ attributedString: NSAttributedString,
        contentSize: CGSize,
        originalMarkdown: String
    ) -> [TextPage] {
        var pages: [TextPage] = []
        let fullLength = attributedString.length
        var currentLocation = 0
        var pageIndex = 0

        // Ensure we have valid content size
        guard contentSize.width > 50 && contentSize.height > 50 else {
            // Return entire text as single page if size is invalid
            let page = TextPage(
                id: 0,
                attributedContent: attributedString,
                markdownContent: originalMarkdown,
                range: NSRange(location: 0, length: fullLength)
            )
            return [page]
        }

        while currentLocation < fullLength {
            // Create fresh text storage with remaining text
            let remainingRange = NSRange(location: currentLocation, length: fullLength - currentLocation)
            let remainingText = attributedString.attributedSubstring(from: remainingRange)

            let textStorage = NSTextStorage(attributedString: remainingText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: contentSize)

            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            // Force layout
            layoutManager.ensureLayout(for: textContainer)

            // Get the glyph range that fits in this container
            let glyphRange = layoutManager.glyphRange(for: textContainer)

            if glyphRange.length == 0 {
                break
            }

            // Convert glyph range to character range
            var actualGlyphRange = NSRange()
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: &actualGlyphRange)

            // Adjust for the offset we're at
            let absoluteRange = NSRange(location: currentLocation + characterRange.location, length: characterRange.length)

            // Try to break at a paragraph or sentence boundary
            let adjustedRange = adjustRangeToBreakPoint(
                attributedString: attributedString,
                proposedRange: absoluteRange
            )

            // Extract the page content
            let pageContent = attributedString.attributedSubstring(from: adjustedRange)
            let markdownSlice = extractMarkdownSlice(from: originalMarkdown, range: adjustedRange)

            let page = TextPage(
                id: pageIndex,
                attributedContent: pageContent,
                markdownContent: markdownSlice,
                range: adjustedRange
            )
            pages.append(page)

            // Move to next page
            currentLocation = adjustedRange.location + adjustedRange.length
            pageIndex += 1

            // Safety check to prevent infinite loops
            if pageIndex > 10000 {
                break
            }
        }

        // Ensure we have at least one page
        if pages.isEmpty && fullLength > 0 {
            let page = TextPage(
                id: 0,
                attributedContent: attributedString,
                markdownContent: originalMarkdown,
                range: NSRange(location: 0, length: fullLength)
            )
            pages.append(page)
        }

        return pages
    }

    /// Adjust range to break at a clean boundary without wasting too much space.
    /// Only searches the last portion of the page to keep pages consistently full.
    private func adjustRangeToBreakPoint(
        attributedString: NSAttributedString,
        proposedRange: NSRange
    ) -> NSRange {
        let text = attributedString.string as NSString
        let endLocation = proposedRange.location + proposedRange.length

        // If we're at the end of the text, use the proposed range
        if endLocation >= text.length {
            return proposedRange
        }

        // Only search the last 15% of the page for clean break points.
        // This keeps pages consistently full while still avoiding mid-word breaks.
        let minBreakLocation = proposedRange.location + (proposedRange.length * 85) / 100
        let searchRange = NSRange(
            location: minBreakLocation,
            length: endLocation - minBreakLocation
        )

        guard searchRange.length > 0 else { return proposedRange }

        // Try to find paragraph break (newline) in the tail
        let paragraphBreak = text.rangeOfCharacter(
            from: CharacterSet.newlines,
            options: .backwards,
            range: searchRange
        )

        if paragraphBreak.location != NSNotFound {
            return NSRange(location: proposedRange.location, length: paragraphBreak.location - proposedRange.location + 1)
        }

        // Try to find sentence break (. ! ?) in the tail
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        let sentenceBreak = text.rangeOfCharacter(
            from: sentenceEnders,
            options: .backwards,
            range: searchRange
        )

        if sentenceBreak.location != NSNotFound {
            let breakEnd = min(sentenceBreak.location + 2, text.length)
            return NSRange(location: proposedRange.location, length: breakEnd - proposedRange.location)
        }

        // Try to find word break (space) in the tail
        let wordBreak = text.rangeOfCharacter(
            from: CharacterSet.whitespaces,
            options: .backwards,
            range: searchRange
        )

        if wordBreak.location != NSNotFound {
            return NSRange(location: proposedRange.location, length: wordBreak.location - proposedRange.location + 1)
        }

        // No good break point found, use proposed range
        return proposedRange
    }

    /// Extract markdown slice corresponding to character range
    private func extractMarkdownSlice(from markdown: String, range: NSRange) -> String {
        // This is a simplified extraction - in a full implementation,
        // we'd maintain a mapping between attributed string ranges and original markdown
        guard let stringRange = Range(range, in: markdown) else {
            // If range conversion fails, return empty string
            // This can happen if markdown was transformed during attribution
            return ""
        }
        return String(markdown[stringRange])
    }
}

// MARK: - Pagination Result
extension TextPaginator {
    /// Result of pagination with metadata
    struct PaginationResult {
        let pages: [TextPage]
        let totalCharacters: Int
        let config: PaginationConfig
        let pageSize: CGSize

        var pageCount: Int { pages.count }
        var isEmpty: Bool { pages.isEmpty }
    }

    /// Paginate with full result metadata
    func paginateWithMetadata(markdown: String, pageSize: CGSize) -> PaginationResult {
        let pages = paginate(markdown: markdown, pageSize: pageSize)
        return PaginationResult(
            pages: pages,
            totalCharacters: markdown.count,
            config: config,
            pageSize: pageSize
        )
    }
}
