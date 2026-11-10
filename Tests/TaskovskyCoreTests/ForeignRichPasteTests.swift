import XCTest
import TaskovskyClipboard
import TaskovskyDomain

final class ForeignRichPasteTests: XCTestCase {
    func testHTMLUsesExactPlainTextAndKeepsSupportedInlineFormatting() throws {
        let html = """
        <head><style>@import url(https://example.invalid/style);</style></head>
        <p> <strong>Bold 🧩 <em>italic e&#769;</em></strong></p>
        <p><a href="https://example.test/review?a=1&amp;b=2">site</a> &amp;
          <a href="javascript:alert(1)">unsafe</a></p>
        <script>ignored</script><span hidden>also ignored</span>
        """
        let plain = "  Bold 🧩 italic e\u{301}\r\n\r\nsite & unsafe\n"
        let result = try XCTUnwrap(ForeignRichPaste.fragment(plain: plain, html: Data(html.utf8), rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(result.text, plain))
        let styled = try RichBodyEdit.applying([.paste(NSRange(location: 0, length: 0), fragment: result)], to: "", rich: nil)
        let text = styled.text as NSString
        func covered(_ value: String, _ include: (RichInlineRun) -> Bool) -> Bool {
            let wanted = text.range(of: value)
            return styled.runs.contains { run in
                include(run) && NSIntersectionRange(NSRange(location: run.location, length: run.length), wanted) == wanted
            }
        }
        XCTAssertTrue(covered("🧩") { $0.bold })
        XCTAssertTrue(covered("italic e\u{301}") { $0.bold && $0.italic })
        XCTAssertTrue(covered("site") { $0.link == "https://example.test/review?a=1&b=2" })
        XCTAssertFalse(covered("unsafe") { $0.link != nil })
        XCTAssertFalse(styled.text.contains("ignored"))
    }

    func testHTMLOnlyPreservesTextAndKnownInlineCSSWithoutLoadingResources() throws {
        let html = """
        <!DOCTYPE html SYSTEM "file:///taskovsky-clipboard-fixture.dtd">
        <p><span style="font-weight:700; font-style:oblique; text-decoration: underline line-through">Text</span></p>
        <p><mark>Mark</mark><br><code>let x = 1</code><img src="https://example.invalid/image.png"></p>
        """
        let result = try XCTUnwrap(ForeignRichPaste.fragment(plain: nil, html: html.data(using: .utf16), rtf: nil))
        XCTAssertEqual(result.text, "Text\nMark\nlet x = 1")
        XCTAssertTrue(result.runs.contains { $0.location == 0 && $0.bold && $0.italic && $0.underline && $0.strikethrough })
        XCTAssertTrue(result.runs.contains { $0.location == 5 && $0.highlight })
        XCTAssertTrue(result.runs.contains { $0.location == 10 && $0.code })
    }

    func testRTFStyleImportAndPlainTextMismatch() throws {
        let rtf = #"{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\f0\fs24\b Bold\b0  \i italic\i0}"#
        let data = Data(rtf.utf8)
        let result = try XCTUnwrap(ForeignRichPaste.fragment(plain: nil, html: nil, rtf: data))
        XCTAssertEqual(result.text, "Bold italic")
        XCTAssertTrue(result.runs.contains { $0.location == 0 && $0.length == 4 && $0.bold })
        XCTAssertTrue(result.runs.contains { $0.location == 5 && $0.length == 6 && $0.italic })
        let html = Data("<em>Different</em>".utf8)
        XCTAssertNotNil(ForeignRichPaste.fragment(plain: "Bold italic", html: html, rtf: data))
        XCTAssertNil(ForeignRichPaste.fragment(plain: "Unrelated", html: html, rtf: data))
        let unstyledHTML = Data("<p>Keep the HTML text</p>".utf8)
        let disagreeing = ForeignRichPaste.fragment(plain: nil, html: unstyledHTML, rtf: data)
        XCTAssertEqual(disagreeing?.text, "Keep the HTML text")
        XCTAssertEqual(disagreeing?.runs, [])
    }

    func testHTMLImportsSemanticParagraphsAndKeepsCodeLinesTogether() throws {
        let html = "<h2>Heading 🧩</h2><blockquote><p>First <strong>quote</strong></p><p>Second quote</p></blockquote>" +
            "<ul><li>Bullet e&#769;</li></ul><ol><li>First number</li><li>Second number</li></ol>" +
            "<pre><code>  let x = 1\n\n  print(x)</code></pre><p>Plain</p>"
        let result = try XCTUnwrap(ForeignRichPaste.fragment(plain: nil, html: Data(html.utf8), rtf: nil))
        let expected = "Heading 🧩\nFirst quote\nSecond quote\nBullet e\u{301}\nFirst number\nSecond number\n  let x = 1\n\n  print(x)\nPlain"
        XCTAssertTrue(RichBody.sameCodeUnits(result.text, expected))
        let styled = try RichBodyEdit.applying([.paste(NSRange(location: 0, length: 0), fragment: result)], to: "", rich: nil)
        let preview = try XCTUnwrap(RichDescriptionPreview(body: styled.text, rich: styled))
        XCTAssertEqual(preview.paragraphs.count, 10)
        XCTAssertEqual(preview.paragraphs[0].heading, 2)
        XCTAssertTrue(preview.paragraphs[1].quote)
        XCTAssertTrue(preview.paragraphs[2].quote)
        XCTAssertEqual(preview.paragraphs[3].marker, .bullet)
        XCTAssertEqual(preview.paragraphs[4].marker, .number(1))
        XCTAssertEqual(preview.paragraphs[5].marker, .number(2))
        let codeID = try XCTUnwrap(preview.paragraphs[6].codeBlockID)
        XCTAssertEqual(preview.paragraphs[7].codeBlockID, codeID)
        XCTAssertEqual(preview.paragraphs[8].codeBlockID, codeID)
        XCTAssertNil(preview.paragraphs[9].codeBlockID)
        XCTAssertTrue(styled.runs.contains(where: \.bold))
    }

    func testHTMLRemapsWholeParagraphsWithoutStylingJoinedPlainLines() throws {
        let html = Data("<h3>Heading 🧩</h3><blockquote><em>Quote e&#769;</em></blockquote>".utf8)
        let plain = "  Heading 🧩 \r\n\r\n\tQuote e\u{301}  "
        let styled = try XCTUnwrap(ForeignRichPaste.fragment(plain: plain, html: html, rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(styled.text, plain))
        let preview = try XCTUnwrap(RichDescriptionPreview(body: plain, rich: styled))
        XCTAssertEqual(preview.paragraphs.map(\.heading), [3, nil, nil])
        XCTAssertEqual(preview.paragraphs.map(\.quote), [false, false, true])

        let joined = "Heading 🧩 Quote e\u{301}"
        let inlineOnly = try XCTUnwrap(ForeignRichPaste.fragment(plain: joined, html: html, rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(inlineOnly.text, joined))
        XCTAssertTrue(inlineOnly.blocks.isEmpty)
        XCTAssertTrue(inlineOnly.runs.contains(where: \.italic))
    }

    func testHTMLCodeAllowsDifferentLineEndingsAndRejectsDifferentIndentation() throws {
        let html = Data("<pre><code>  let x = 1\n\n  print(x)</code></pre>".utf8)
        let exact = "  let x = 1\r\n\r\n  print(x)"
        let code = try XCTUnwrap(ForeignRichPaste.fragment(plain: exact, html: html, rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(code.text, exact))
        XCTAssertEqual(code.blocks.count, 3)
        XCTAssertEqual(Set(code.blocks.compactMap(\.codeBlockID)).count, 1)

        let mixedHTML = Data("<h3>Heading</h3><pre><code>  let x = 1\n\n  print(x)</code></pre>".utf8)
        let mixed = "  Heading \r\n\r\n  let x = 1\r\n\r\n  print(x)"
        let both = try XCTUnwrap(ForeignRichPaste.fragment(plain: mixed, html: mixedHTML, rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(both.text, mixed))
        XCTAssertEqual(both.blocks.filter { $0.codeBlockID != nil }.count, 3)
        XCTAssertEqual(both.blocks.first?.heading, 3)

        let reindented = "let x = 1\n\n  print(x)"
        let literal = try XCTUnwrap(ForeignRichPaste.fragment(plain: reindented, html: html, rtf: nil))
        XCTAssertTrue(RichBody.sameCodeUnits(literal.text, reindented))
        XCTAssertTrue(literal.blocks.isEmpty)
    }

    func testHTMLParagraphStylesKeepComplementaryRTFInlineStyles() throws {
        let html = Data("<h2>Title</h2>".utf8)
        let rtf = Data(#"{\rtf1\ansi \b Title\b0}"#.utf8)
        let result = try XCTUnwrap(ForeignRichPaste.fragment(plain: "Title", html: html, rtf: rtf))
        XCTAssertEqual(result.blocks.map(\.heading), [2])
        XCTAssertTrue(result.runs.contains(where: \.bold))
    }

    func testForeignImportRefusesObjectsBadEncodingAndOversizedData() {
        let object = #"{\rtf1\ansi {\object{\objdata 00}} Text}"#
        let external = #"{\rtf1\ansi {\field{\*\fldinst INCLUDETEXT "file:///taskovsky.txt"}{\fldrslt Text}}}"#
        for rtf in [object, external] {
            XCTAssertNil(ForeignRichPaste.fragment(plain: "Text", html: nil, rtf: Data(rtf.utf8)))
        }
        for html in [Data([0xff]), Data(repeating: 32, count: 1_048_577), Data("<b>A\u{0000}B</b>".utf8)] {
            XCTAssertNil(ForeignRichPaste.fragment(plain: nil, html: html, rtf: nil))
        }
    }
}
