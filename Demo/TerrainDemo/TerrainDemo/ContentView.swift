import SwiftUI

/// Root view: full-screen terrain with an overlay control panel.
/// Portrait -> panel docks at the bottom. Landscape -> panel docks on the right.
struct ContentView: View {
    @State private var seedText = "1337"
    @State private var seed: UInt64 = 1337
    @State private var rebuildToken = 0
    @State private var preset: BiomePreset = .default
    @State private var structuresEnabled = true
    @State private var wireframe = false
    @State private var showsWater = true
    @State private var fps: Double = 0
    @State private var panelVisible = true
    @State private var dragMode: DragMode = .orbit

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                TerrainView(
                    seed: $seed,
                    rebuildToken: $rebuildToken,
                    preset: $preset,
                    structuresEnabled: $structuresEnabled,
                    wireframe: $wireframe,
                    showsWater: $showsWater,
                    fps: $fps,
                    dragMode: $dragMode
                )
                .ignoresSafeArea()

                // Show/hide button (top-right, always reachable)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { panelVisible.toggle() }) {
                            Text(panelVisible ? "Hide Controls" : "Show Controls")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                        }
                        .background(Color.black.opacity(0.78))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding()
                    Spacer()
                }

                // Control panel
                if panelVisible {
                    if isLandscape {
                        HStack {
                            Spacer()
                            ScrollView {
                                panel
                                    .frame(width: 340)
                            }
                            .padding(.vertical)
                        }
                        .padding(.trailing)
                    } else {
                        VStack {
                            Spacer()
                            panel
                        }
                        .padding()
                    }
                }
            }
        }
    }

    private var panel: some View {
        ControlPanel(
            seedText: $seedText,
            preset: $preset,
            structuresEnabled: $structuresEnabled,
            wireframe: $wireframe,
            showsWater: $showsWater,
            fps: fps,
            dragMode: $dragMode,
            onRegenerate: regenerate
        )
    }

    /// Applies the seed field (or a random seed when it is blank/invalid)
    /// and forces a full world rebuild.
    private func regenerate() {
        let trimmed = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = UInt64(trimmed), !trimmed.isEmpty {
            seed = value
        } else {
            let value = UInt64.random(in: 1 ... 999_999)
            seed = value
            seedText = String(value)
        }
        rebuildToken += 1
    }
}
