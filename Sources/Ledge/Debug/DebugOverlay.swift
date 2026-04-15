import SwiftUI

struct DebugOverlay: View {
    let screen: ScreenDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(screen.localizedName)
            Text("id \(screen.displayID)")
            if let rect = NotchGeometry.notchRect(for: screen, synthetic: FeatureFlags.syntheticNotch) {
                Text("\(Int(rect.width))×\(Int(rect.height))")
            }
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
