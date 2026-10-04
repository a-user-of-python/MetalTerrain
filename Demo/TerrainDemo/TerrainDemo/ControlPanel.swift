import SwiftUI

/// Bottom/side control panel for the terrain demo.
/// Large type, high contrast — designed for low vision.
struct ControlPanel: View {
    @Binding var seedText: String
    @Binding var preset: BiomePreset
    @Binding var structuresEnabled: Bool
    @Binding var wireframe: Bool
    @Binding var showsWater: Bool
    var fps: Double
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
