import Foundation

enum FontPropertiesAttribute: AttributedStringKey {
  typealias Value = FontProperties
  static let name = "fontProperties"
}

extension AttributeScopes {
  var markdownUI: MarkdownUIAttributes.Type {
    MarkdownUIAttributes.self
  }

  struct MarkdownUIAttributes: AttributeScope {
    let swiftUI: SwiftUIAttributes
    let fontProperties: FontPropertiesAttribute
  }
}

extension AttributeDynamicLookup {
  subscript<T: AttributedStringKey>(
    dynamicMember keyPath: KeyPath<AttributeScopes.MarkdownUIAttributes, T>
  ) -> T {
    return self[T.self]
  }
}

extension AttributedString {
  func resolvingFonts() -> AttributedString {
    var output = self

    for run in output.runs {
      guard let fontProperties = run.fontProperties else {
        continue
      }
      // Pulse fork patch (2026-04-27): skip setting `.font` as a per-run
      // attribute when the resolved properties match the absolute default
      // (plain body text — no code, no heading, no emphasis, no italic,
      // no size override). `Text(AttributedString)` with an explicit `.font`
      // attribute does NOT fall back to AppleColorEmoji for emoji
      // codepoints in that run on iOS 17/18/26 — emojis render as tofu
      // (.notdef). Letting the SwiftUI environment font apply instead
      // (set via `.font(.system(size: 15))` on the wrapping view)
      // preserves the system font's automatic emoji fallback chain.
      // Code / headings / emphasis still get explicit fonts since their
      // FontProperties differ from the default.
      // DIAGNOSTIC: log what's happening at runtime so Pulse can confirm
      // whether the default-skip path is firing. Remove once verified.
      let runText = String(output[run.range].characters)
      let isDefault = (fontProperties == FontProperties())
      let isEmojiRun = runText.unicodeScalars.contains(where: { $0.value > 0xFFFF })
      if isEmojiRun || isDefault {
        print("PULSE-MD run text=\(runText.prefix(40)) default=\(isDefault) emoji=\(isEmojiRun) props=size:\(fontProperties.size) family:\(fontProperties.family) weight:\(fontProperties.weight) variant:\(fontProperties.familyVariant)")
      }
      if isDefault {
        output[run.range].fontProperties = nil
        continue
      }
      output[run.range].font = .withProperties(fontProperties)
      output[run.range].fontProperties = nil
    }

    return output
  }
}
