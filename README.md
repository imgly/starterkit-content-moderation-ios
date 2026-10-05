# Content Moderation Editor Starter Kit for iOS

Content moderation made easy. Decide what imagery and wording to restrict and receive automatic notifications flagging content that might be violating your guidelines. Built with [CE.SDK](https://img.ly/creative-sdk) by [IMG.LY](https://img.ly).

<p>
  <a href="https://img.ly/docs/cesdk/ios/quickstart/">Documentation</a> |
  <a href="https://img.ly/demos/content-moderation/web/">Live Demo (Web)</a>
</p>

## Getting Started

### Prerequisites

- [Xcode](https://developer.apple.com/xcode/)
- Swift 6+
- iOS 16+ deployment target
- An IMG.LY API key (`sk_…`) from the [IMG.LY Dashboard](https://img.ly/dashboard) — the moderation check cannot run without one

### Clone the Repository

```bash
git clone https://github.com/imgly/starterkit-content-moderation-ios.git
cd starterkit-content-moderation-ios
```

### Open in Xcode

```bash
open StarterKit-ContentModerationEditor.xcodeproj
```

Xcode will resolve the Swift Package dependencies automatically. Select an iOS Simulator or device and press **Run** (Cmd+R).

## Configuration

### License Key

Add your CE.SDK license key in `StarterKit-ContentModerationEditor/Secrets.swift`:

```swift
let secrets = Secrets(
  // ...
  licenseKey: "your-license-key"
)
```

Without a license key, the editor runs in evaluation mode with a watermark.

## How Content Moderation Works

Tapping **Validate Content** in the navigation bar opens the moderation panel. Opening it does not start a check — the user runs it explicitly with the button at the bottom of the sheet. A run then:

1. **Finds every moderatable block** in the current scene — image blocks and text blocks
2. **Sends each one** to a content moderation API — an image by URL when it is remotely hosted, by uploading it first when it lives on the device; a text block as the string itself
3. **Displays results grouped by block**, each flagged category carrying a severity indicator (certain, likely)
4. **Allows block selection** to quickly navigate to flagged content

The navigation bar icon shows a checkmark shield for one state only — a completed run that found nothing and left nothing unchecked. Never validated, changed since validation, flagged, and partly unchecked all show a warning shield, because in each of them nothing vouches for what is on the canvas. A run in flight shows a spinner. The accessibility label says which state it is. Changing an image or editing a caption marks the design as needing validation again.

Export is gated on the check. If the design was never validated, or its content changed since the last run, an alert offers to validate first — or to export anyway. Remove the **Export Anyway** button in `ModerationExportAlert.swift` if unvalidated export must be impossible. A validated design opens the results panel instead of exporting when it still contains violations, or when any block could not be checked at all: a block nobody checked is unknown, not clean, so it does not certify a design.

Only `failed` results (red, *Certain*) block export. `warning` results (orange, *Likely*) are listed in the panel, but do not stop an export. The count next to the icon is a count of *blocks* with findings, not of categories: one caption that trips toxic, insulting and violent at once is one problem for the user to fix, not three.

Results are cached per checked item — an image URL or a string of text — for the lifetime of the service, so re-running validation on an unchanged design issues no request and costs no credits. Installing a different service with `setService(_:)` discards both the cache and the previous outcome.

### Content Categories

Images and text are scored against separate category sets. The thresholds are the same for both.

#### Images

| Category          | Description                                                 | Threshold                     |
| ----------------- | ----------------------------------------------------------- | ----------------------------- |
| Weapons           | Handguns, rifles, machine guns, threatening knives           | >80% = failed, >40% = warning |
| Alcohol           | Wine, beer, cocktails, champagne                             | >80% = failed, >40% = warning |
| Drugs             | Cannabis, syringes, glass pipes, bongs, pills                | >80% = failed, >40% = warning |
| Nudity            | Raw or partial nudity                                        | >80% = failed, >40% = warning |
| Offensive symbols | Nazi symbols, swastikas, confederate flags, offensive gestures | >80% = failed, >40% = warning |
| Gore              | Blood, wounds, serious injuries, corpses, skulls              | >80% = failed, >40% = warning |

Drugs spans two provider models: `recreational_drug` (cannabis and street drugs) and `medical` (pills, blisters, syringes). The category reports whichever scores higher.

#### Text

| Category                | Description                                               | Threshold                     |
| ----------------------- | --------------------------------------------------------- | ----------------------------- |
| Toxic Language          | Language likely to make someone leave the conversation    | >80% = failed, >40% = warning |
| Insulting Language      | Insults, name-calling, and demeaning remarks              | >80% = failed, >40% = warning |
| Discriminatory Language | Language that demeans a group or protected characteristic | >80% = failed, >40% = warning |
| Violent Language        | Threats of violence and calls to harm someone             | >80% = failed, >40% = warning |
| Sexual Language         | Sexually explicit or suggestive wording                   | >80% = failed, >40% = warning |
| Self-Harm               | References to suicide, self-injury, or eating disorders   | >80% = failed, >40% = warning |

Text categories overlap far more than image ones — an insulting sentence usually scores as toxic too — so a single text block commonly trips several at once. That is why the panel groups findings under the block they belong to.

The service reports only the categories the model actually returned a score for. A category the provider omits is treated as *unknown* and left out of the results rather than shown as passing — a missing row is not an all-clear. If a response carries no known category at all, the run fails rather than reporting the image as clean.

Thresholds are a single pair applied to every category, not per-category. `ModerationThresholds` ships `strict`, `moderate` (the default) and `relaxed` presets in `StarterKit/moderation/ModerationTypes.swift`; see `StarterKit/examples/ExampleCustomThresholds.swift` for stricter, more relaxed and fully custom services.

### Configuring the Moderation Service

The default `GatewayModerationService` runs the `imgly/detection` model through the [IMG.LY AI Gateway](https://img.ly/docs/cesdk/ios/user-interface/ai-integration-5aa356/). The gateway handles provider routing, credentials and billing, so the only thing you supply is an IMG.LY API key (`sk_…`) from the [IMG.LY Dashboard](https://img.ly/dashboard) — no separate moderation provider account and no proxy of your own.

Set it in `Secrets.swift`:

```swift
let secrets = Secrets(
  // ...
  gatewayApiKey: "sk_live_your_key_here",
)
```

`ContentModerationEditorStarterKit` reads that key and creates the store the editor uses:

```swift
@StateObject private var moderation = ModerationStore(
  service: GatewayModerationService(apiKey: secrets.gatewayApiKey, thresholds: .moderate),
)

// ...

Editor(settings)
  .imgly.configuration {
    ContentModerationEditorConfiguration(moderation: moderation)
  }
```

The store belongs to one editor, so two editors never share a verdict. Created without a service it holds one with no key, which fails every check with a missing-key error rather than reporting content as clean. A host that collects the key at runtime keeps a reference to the store and calls `setService(_:)` once the user supplies one.

An API key shipped inside an app binary can be extracted, so keep it out of source control. For production, consider calling the gateway from your own backend instead and implementing `ModerationService` against it — which is also how you connect an entirely different provider:

```swift
struct MyModerationService: ModerationService {
  func check(_ content: ModerationContent) async throws -> [ModerationCheckResult] {
    switch content {
    case let .image(url):
      try await checkImage(url) // Your backend, mapped to ModerationCheckResult values.
    case let .text(text):
      try await checkText(text)
    }
  }
}
```

`ModerationContent` is the single unit of work: one image or one string. `canCheck(_:)` has a default implementation that accepts `http(s)` images and non-empty text — override it to decline anything your backend cannot handle, and it is reported as unchecked rather than passing silently.

Install it the same way, with `ModerationStore(service: MyModerationService())`.

### Limitations

Images that live on the device — anything added from the photo roll, the camera or an upload source — are uploaded to the gateway so they can be checked too. User-supplied content is the most likely to violate a policy, so leaving it unchecked would be the wrong default.

**This means the user's photo leaves the device — and so does the text of every text block.** Captions travel in the request body on every run. Say so in your privacy policy. `uploadsLocalFiles: false` keeps local images on the device — they are then declined, and anything the service declines to check is reported as unchecked and blocks export rather than passing silently — but it does not affect text, which is always sent:

```swift
GatewayModerationService(apiKey: secrets.gatewayApiKey, uploadsLocalFiles: false)
```

Text blocks are checked as well, and their content travels in the request body — no upload step, and fewer provider operations than an image.

An image the service cannot reach at all — a file the system has evicted from the cache, or a remote URL that no longer resolves — is reported as "not checkable" for the same reason.

Only image and text blocks are checked; a page-level image fill is neither moderated nor fingerprinted. Images and text are sent as separate requests rather than batched into one call.

## Customization

The starter kit files in `StarterKit/` demonstrate how to customize the editor:

- **Configuration** — `ContentModerationEditorConfiguration.swift`
- **Moderation** — `moderation/` (types, service protocol, scene scanner, shared state, results panel UI)
- **Callbacks** — `callbacks/` (onCreate, onLoaded with reset and change tracking, onExport with validation gate)
- **Components** — `components/` (navigation bar with validate button, dock, inspector bar, canvas menu)
- **Examples** — `examples/` (alternative threshold presets)

## Architecture

```
starterkit-content-moderation-ios/
├── StarterKit-ContentModerationEditor.xcodeproj/
├── StarterKit-ContentModerationEditor/   # App entry point
│   ├── StarterKit_ContentModerationEditorApp.swift
│   ├── ContentView.swift
│   └── Secrets.swift
└── StarterKit/                           # Copyable editor configuration
    ├── ContentModerationEditorStarterKit.swift
    ├── ContentModerationEditorConfiguration.swift
    ├── moderation/
    │   ├── ModerationTypes.swift
    │   ├── ModerationService.swift
    │   ├── ModerationScanner.swift
    │   ├── ModerationStore.swift
    │   └── ui/
    ├── callbacks/
    ├── components/
    ├── examples/
    │   └── ExampleCustomThresholds.swift
    └── content-moderation-example.scene
```

## Key Capabilities

- Validate every image and every text block in a design against a content moderation API
- Results grouped by block, each with per-category severity, most severe first
- Export gated on the design being validated, violation-free and fully checked
- Swappable moderation provider behind a `ModerationService` protocol with a single required method
- Configurable thresholds via `ModerationThresholds`

## Documentation

For complete integration guides and API reference, visit the [CE.SDK iOS Documentation](https://img.ly/docs/cesdk/ios/).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details. The CE.SDK itself is a commercial product; [sign up for a free trial](https://img.ly/forms/free-trial) to get a license key.

<p align="center">Built with <a href="https://img.ly/products/creative-sdk?utm_campaign=starterkit-content-moderation-editor">CE.SDK</a> by <a href="https://img.ly">IMG.LY</a></p>
