import SwiftUI

/// Bottom/side control panel for the terrain demo.
/// Large type, high contrast — designed for low vision.
struct ControlPanel: View {
    @Binding var seedText: String
    @Binding var preset: BiomePreset
    @Binding var structuresEnabled: Bool
    @Binding var wireframe: Bool
    @Binding var showsWater: Bool
    @Binding var fogEnabled: Bool
    @Binding var viewDistance: Int
    var fps: Double
    @Binding var dragMode: DragMode
    var onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TERRAIN CONTROLS")
                .font(.title2)
                .bold()

            // Seed + regenerate
            HStack(spacing: 12) {
                Text("Seed")
                    .font(.title3)
                TextField("1337", text: $seedText)
                    .font(.title2)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                    .foregroundColor(.black)
                Spacer()
                Button(action: onRegenerate) {
                    Text("Regenerate")
                        .font(.title3)
                        .bold()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }

            // Biome preset picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Biome")
                    .font(.title3)
                Picker("Biome", selection: $preset) {
                    ForEach(BiomePreset.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Toggles
            Toggle("Structures", isOn: $structuresEnabled)
                .font(.title3)
            Toggle("Wireframe", isOn: $wireframe)
                .font(.title3)
            Toggle("Water", isOn: $showsWater)
                .font(.title3)
            Toggle("Fog", isOn: $fogEnabled)
                .font(.title3)

            // Render distance (chunks radius)
            VStack(alignment: .leading, spacing: 6) {
                Text("Render distance: \(viewDistance)")
                    .font(.title3)
                Slider(value: Binding(
                    get: { Double(viewDistance) },
                    set: { viewDistance = Int($0) }
                ), in: 2...16, step: 1)
                .tint(.blue)
            }

            // Mac: pick what mouse-drag does (no two-finger touch on desktop).
            #if targetEnvironment(macCatalyst)
            VStack(alignment: .leading, spacing: 6) {
                Text("Mouse drag")
                    .font(.title3)
                Picker("Mouse drag", selection: $dragMode) {
                    ForEach(DragMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Text("Arrows pan · +/− zoom · 0 resets · trackpad pinch zooms")
                    .font(.callout)
                    .opacity(0.75)
            }
            #endif

            // FPS readout
            Text("\(Int(fps)) FPS")
                .font(.title2)
                .bold()
                .monospacedDigit()
        }
        .padding(20)
        .background(Color.black.opacity(0.78))
        .foregroundColor(.white)
        .cornerRadius(18)
    }
}
