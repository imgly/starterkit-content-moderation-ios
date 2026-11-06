import IMGLYEditor
import IMGLYEngine
import SwiftUI

// MARK: - Starter Kit View

struct ContentModerationEditorStarterKit: View {
  // Provide `EngineSettings` with your license and an optional userId.
  let settings = EngineSettings(
    license: secrets.licenseKey, // Use nil for evaluation mode with watermark
    userID: "<your unique user id>",
  )

  // Moderation state for this editor, pointed at the IMG.LY AI Gateway with the key
  // from `Secrets.swift`. Swap in your own `ModerationService` here to use a
  // different provider. Held as `@StateObject` so it survives re-renders — the
  // editor's verdict must not be discarded every time this view's body runs.
  @StateObject private var moderation = ModerationStore(
    service: GatewayModerationService(apiKey: secrets.gatewayApiKey, thresholds: .moderate),
  )

  var body: some View {
    Editor(settings)
      .imgly.configuration {
        ContentModerationEditorConfiguration(moderation: moderation)
      }
  }
}

// MARK: - Preview

#Preview {
  ContentModerationEditorStarterKit()
}
