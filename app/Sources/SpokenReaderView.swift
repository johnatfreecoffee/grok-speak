import AppKit
import SwiftUI

struct SpokenWord: Codable, Equatable {
    var text: String
    var start: Double
    var end: Double
    var from: Int
    var to: Int

    var nsRange: NSRange {
        NSRange(location: max(0, from), length: max(0, to - from))
    }
}

struct TimestampFile: Codable {
    var text: String
    var duration: Double?
    var words: [SpokenWord]
}

private let skyNS = NSColor(srgbRed: 14 / 255, green: 165 / 255, blue: 233 / 255, alpha: 1)

final class ClickTextView: NSTextView {
    var words: [SpokenWord] = []
    var onWord: ((SpokenWord) -> Void)?
    private var highlighted: Int?

    override func mouseDown(with event: NSEvent) {
        guard let layoutManager, let textContainer else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        var fraction: CGFloat = 0
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        let charIdx = layoutManager.characterIndexForGlyph(at: glyph)
        if let word = words.last(where: { charIdx >= $0.from && charIdx < $0.to })
            ?? words.last(where: { charIdx >= $0.from })
        {
            onWord?(word)
            return
        }
        super.mouseDown(with: event)
    }

    func replaceSpoken(_ text: String, words: [SpokenWord]) {
        self.words = words
        highlighted = nil
        string = text
        let all = NSRange(location: 0, length: (text as NSString).length)
        if let storage = textStorage {
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: all)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: all)
            storage.addAttribute(.backgroundColor, value: NSColor.clear, range: all)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 6
            para.paragraphSpacing = 8
            storage.addAttribute(.paragraphStyle, value: para, range: all)
        }
        if let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let used = layoutManager.usedRect(for: textContainer)
            let extra = textContainerInset.height * 2 + 16
            frame.size.height = max(used.height + extra, enclosingScrollView?.contentSize.height ?? 0)
        }
    }

    func highlight(_ index: Int?) {
        guard let storage = textStorage else { return }
        let all = NSRange(location: 0, length: storage.length)
        if highlighted != index {
            storage.removeAttribute(.backgroundColor, range: all)
            storage.removeAttribute(.font, range: all)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: all)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: all)
        }
        if let index, words.indices.contains(index) {
            let range = words[index].nsRange
            if range.location + range.length <= storage.length, range.length > 0 {
                storage.addAttribute(.backgroundColor, value: skyNS.withAlphaComponent(0.28), range: range)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .semibold), range: range)
                storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                if highlighted != index {
                    scrollRangeToVisible(range)
                }
            }
        }
        highlighted = index
    }
}

struct SpokenReaderView: NSViewRepresentable {
    var spoken: String
    var words: [SpokenWord]
    var activeIndex: Int?
    var onSelect: (SpokenWord) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let tv = ClickTextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isRichText = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textContainerInset = NSSize(width: 10, height: 10)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 4
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.autoresizingMask = [.width]
        tv.onWord = onSelect
        context.coordinator.textView = tv

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView ?? scroll.documentView as? ClickTextView else { return }
        tv.onWord = onSelect
        tv.words = words
        if tv.string != spoken {
            tv.replaceSpoken(spoken, words: words)
        }
        tv.highlight(activeIndex)
        let width = scroll.contentView.bounds.width
        if width > 0 {
            tv.frame.size.width = width
        }
    }

    final class Coordinator {
        var textView: ClickTextView?
    }
}
