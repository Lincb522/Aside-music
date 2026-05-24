import SwiftUI

struct MonoWordmarkImage: View {
    @Environment(\.colorScheme) private var colorScheme

    var height: CGFloat
    var preferredColorScheme: ColorScheme?

    private var assetName: String {
        (preferredColorScheme ?? colorScheme) == .dark ? "MonoTextWhite" : "MonoTextBlack"
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: height * 3.62, height: height)
            .accessibilityLabel("Mono")
    }
}
