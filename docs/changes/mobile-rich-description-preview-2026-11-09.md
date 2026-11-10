# Mobile rich description preview

This change implements the IOS-008 read-only rendering gate for known rich descriptions. Task and note detail use a native selectable preview. Template capture uses the same preview when the body is protected.

Render inline emphasis, underline, strike, highlight, code and links. Render six heading levels, quotes, bullet and numbered lists, checked and unchecked rich checklist paragraphs, and horizontal rules. Draw paragraph decorations separately from the text. Copying the description preserves its original Unicode and line breaks.

Validate the mirrored text and every UTF-16 range before applying formatting. Unsupported or malformed descriptions show their authoritative plain body and a reason. The preview has no editor or save callback. Independent field changes still pass the repository compatibility gate and preserve the complete rich payload. Rich authoring remains outside this initial phone write scope.
