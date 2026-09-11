<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
  GENERATED — do not edit. Rewritten from this template by
  overrides/hooks/theme-set.d/yazi-syntax.sh on every `omarchy theme set`.

  yazi's previewer highlights through syntect, which reads a TextMate .tmTheme,
  and a .tmTheme holds literal hex only. Left unset, yazi highlights in the
  terminal's ANSI palette instead — fewer colours, but live. This file buys the
  full palette back at the cost of needing regeneration per theme, which is what
  the hook is for.

  Scope assignment follows Xcode's default rather than inventing one, because
  that is the macOS reference these themes are reconstructing: strings salmon
  (systemRed), keywords pink (systemPurple), numbers gold (systemYellow),
  preprocessor orange (systemOrange), and — the distinction Xcode actually makes
  — PROJECT symbols teal against SYSTEM symbols purple. TextMate scopes carry
  that split already: `entity.name.*` is what the file defines, `support.*` is
  what it borrows from a library.
-->
<plist version="1.0">
<dict>
  <key>name</key><string>cllpse-macos</string>
  <key>settings</key>
  <array>

    <dict>
      <key>settings</key>
      <dict>
        <key>background</key><string>{{ background }}</string>
        <key>foreground</key><string>{{ foreground }}</string>
        <key>caret</key><string>{{ accent }}</string>
        <key>selection</key><string>{{ selection }}</string>
        <key>lineHighlight</key><string>{{ line_highlight }}</string>
        <key>invisibles</key><string>{{ comment }}</string>
      </dict>
    </dict>

    <dict>
      <key>name</key><string>Comment</string>
      <key>scope</key><string>comment, punctuation.definition.comment</string>
      <key>settings</key><dict><key>foreground</key><string>{{ comment }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>String</string>
      <key>scope</key><string>string, string.quoted, punctuation.definition.string</string>
      <key>settings</key><dict><key>foreground</key><string>{{ string }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Regular expression</string>
      <key>scope</key><string>string.regexp, constant.character.escape</string>
      <key>settings</key><dict><key>foreground</key><string>{{ regexp }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Number</string>
      <key>scope</key><string>constant.numeric</string>
      <key>settings</key><dict><key>foreground</key><string>{{ number }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Language constant</string>
      <key>scope</key><string>constant.language, constant.character, constant.other, variable.language</string>
      <key>settings</key><dict><key>foreground</key><string>{{ keyword }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Keyword and storage</string>
      <key>scope</key><string>keyword, keyword.control, storage, storage.type, storage.modifier</string>
      <key>settings</key><dict><key>foreground</key><string>{{ keyword }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Operator and punctuation</string>
      <key>scope</key><string>keyword.operator, punctuation, meta.brace</string>
      <key>settings</key><dict><key>foreground</key><string>{{ foreground }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Project symbol — defined here (Xcode teal)</string>
      <key>scope</key><string>entity.name.function, entity.name.type, entity.name.class, entity.name.struct, entity.name.enum, entity.name.trait, meta.function-call</string>
      <key>settings</key><dict><key>foreground</key><string>{{ project_symbol }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>System symbol — from a library (Xcode purple)</string>
      <key>scope</key><string>support.function, support.class, support.type, support.constant, support.variable</string>
      <key>settings</key><dict><key>foreground</key><string>{{ system_symbol }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Variable and parameter</string>
      <key>scope</key><string>variable, variable.parameter, variable.other, meta.definition.variable</string>
      <key>settings</key><dict><key>foreground</key><string>{{ foreground }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Preprocessor</string>
      <key>scope</key><string>meta.preprocessor, keyword.other.preprocessor, keyword.control.import, keyword.control.at-rule</string>
      <key>settings</key><dict><key>foreground</key><string>{{ preprocessor }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Markup / HTML tag</string>
      <key>scope</key><string>entity.name.tag</string>
      <key>settings</key><dict><key>foreground</key><string>{{ keyword }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Attribute name</string>
      <key>scope</key><string>entity.other.attribute-name</string>
      <key>settings</key><dict><key>foreground</key><string>{{ project_symbol }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Inherited / parent class</string>
      <key>scope</key><string>entity.other.inherited-class</string>
      <key>settings</key><dict><key>foreground</key><string>{{ system_symbol }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Heading</string>
      <key>scope</key><string>markup.heading, markup.heading entity.name</string>
      <key>settings</key><dict><key>foreground</key><string>{{ accent }}</string><key>fontStyle</key><string>bold</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Emphasis</string>
      <key>scope</key><string>markup.bold</string>
      <key>settings</key><dict><key>fontStyle</key><string>bold</string></dict>
    </dict>
    <dict>
      <key>name</key><string>Italic</string>
      <key>scope</key><string>markup.italic</string>
      <key>settings</key><dict><key>fontStyle</key><string>italic</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Link</string>
      <key>scope</key><string>markup.underline.link, string.other.link</string>
      <key>settings</key><dict><key>foreground</key><string>{{ accent }}</string><key>fontStyle</key><string>underline</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Diff inserted</string>
      <key>scope</key><string>markup.inserted</string>
      <key>settings</key><dict><key>foreground</key><string>{{ inserted }}</string></dict>
    </dict>
    <dict>
      <key>name</key><string>Diff deleted</string>
      <key>scope</key><string>markup.deleted</string>
      <key>settings</key><dict><key>foreground</key><string>{{ string }}</string></dict>
    </dict>

    <dict>
      <key>name</key><string>Invalid</string>
      <key>scope</key><string>invalid, invalid.illegal</string>
      <key>settings</key><dict><key>foreground</key><string>{{ invalid }}</string></dict>
    </dict>

  </array>
</dict>
</plist>
