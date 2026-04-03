import SwiftUI
import QuickLook

struct StarterModel: Identifiable {
    let id = UUID()
    let name: String
    let fileName: String
    let icon: String

    var url: URL? {
        Bundle.main.url(forResource: fileName, withExtension: "usdz")
    }
}

struct ModelPickerSheet: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    private let models: [StarterModel] = {
        // Dynamically find all .usdz files in the bundle
        var found: [StarterModel] = []
        if Bundle.main.url(forResource: "toy_biplane_realistic", withExtension: "usdz") != nil {
            found.append(StarterModel(name: "Biplane", fileName: "toy_biplane_realistic", icon: "airplane"))
        }
        if Bundle.main.url(forResource: "toy_car", withExtension: "usdz") != nil {
            found.append(StarterModel(name: "Car", fileName: "toy_car", icon: "car.fill"))
        }
        return found
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(models) { model in
                        Button {
                            if let url = model.url {
                                onSelect(url)
                                dismiss()
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: model.icon)
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue)
                                    .frame(height: 60)

                                Text(model.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("3D Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
