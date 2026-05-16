import SwiftUI
import AVKit

/// SwiftUI bridge for `AVRoutePickerView` — Apple's official "AirPlay" button
/// that, when clicked, presents the same picker Control Center uses for
/// audio/video routing. Unlike CoreAudio's enumeration (which only sees
/// devices currently routed to), this taps into the live AirPlay discovery
/// stream, so HomePods, Apple TVs, Sonos endpoints, etc. appear even when
/// you haven't routed audio to them yet.
struct AirPlayPickerButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isRoutePickerButtonBordered = false
        // Make the glyph match our muted/secondary tone. Active routing
        // tint is controlled by the system on macOS.
        view.setRoutePickerButtonColor(NSColor(Palette.secondary), for: .normal)
        view.setRoutePickerButtonColor(NSColor(Palette.primary), for: .normalHighlighted)
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
