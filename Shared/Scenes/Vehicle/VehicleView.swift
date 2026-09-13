//
//  VehicleView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 21/3/22.
//

import SwiftUI

struct VehicleView: View {
    
    let stationsViewModel: StationsListViewViewModel
    var onSave: (() -> Void)?
    
    @State private var viewModel = DefaultVehicleViewViewModel()
    @State private var showRemoveVehicleAlert: Bool = false
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case brand, model, capacity
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isSaved {
                    fillCostSection
                } else {
                    introSection
                }
                vehicleSection
                tankSection
                actionsSection
            }
            .platformFormStyle()
            .navigationTitle("myVehicle.brand.title".translated)
            .alert("myVehicle.saved.message".translated, isPresented: $viewModel.showSuccessAlert) {
                Button("common.ok".translated) { }
            }
            .alert("myVehicle.remove.alert.title".translated, isPresented: $showRemoveVehicleAlert) {
                Button("myVehicle.remove".translated, role: .destructive) {
                    viewModel.removeVehicle()
                    onSave?()
                }
                Button("common.cancel".translated, role: .cancel) { }
            }
#if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done".translated) { focusedField = nil }
                }
            }
#endif
        }
    }
}

private extension VehicleView {
    
    @ViewBuilder
    var fillCostSection: some View {
        Section {
            if let cost = viewModel.fillCost(using: stationsViewModel.nearbyStations()),
               let unit = cost.cheapestStation.price(for: viewModel.vehicleData.fuel) {
                FillCostCard(station: cost.cheapestStation,
                             fuel: viewModel.vehicleData.fuel,
                             pricePerLitre: unit,
                             fillCost: cost.cheapest)
                    .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                    .listRowBackground(Color.clear)
            } else {
                Label("myVehicle.fill.unavailable".translated, systemImage: "fuelpump.slash")
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(viewModel.vehicleData.displayName)
        } footer: {
            Text("myVehicle.fill.footer".translated)
        }
    }
    
    var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("myVehicle.ad.title".translated, systemImage: "car.fill")
                    .font(.customSize(17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("myVehicle.ad.description".translated)
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }
}

private extension VehicleView {
    
    var vehicleSection: some View {
        Section {
            LabeledRow(icon: "tag.fill", title: "myVehicle.brand.placeholder".translated) {
                PromptField(prompt: "myVehicle.brand.example".translated,
                            text: $viewModel.vehicleData.brand)
                    .focused($focusedField, equals: .brand)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .model }
            }
            LabeledRow(icon: "car.fill", title: "myVehicle.model.placeholder".translated) {
                PromptField(prompt: "myVehicle.model.example".translated,
                            text: $viewModel.vehicleData.model)
                    .focused($focusedField, equals: .model)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .capacity }
            }
        } header: {
            Text("myVehicle.section.vehicle".translated)
        } footer: {
            Text("myVehicle.section.vehicle.hint".translated)
        }
    }
    
    var tankSection: some View {
        Section {
            Picker(selection: $viewModel.vehicleData.fuel) {
                ForEach(viewModel.allFuelTypes, id: \.self) { fuel in
                    Text(fuel.name).tag(fuel)
                }
            } label: {
                Label("common.fuelType".translated, systemImage: "fuelpump.fill")
                    .foregroundStyle(.primary)
            }
            LabeledRow(icon: "drop.fill", title: "myVehicle.capacity.placeholder".translated) {
                HStack(spacing: 4) {
                    PromptField(prompt: "myVehicle.capacity.example".translated,
                                text: $viewModel.vehicleData.capacity)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .focused($focusedField, equals: .capacity)
                    Text("myVehicle.capacity.unit".translated)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("myVehicle.section.tank".translated)
        } footer: {
            if !viewModel.vehicleData.capacity.isEmpty && !viewModel.vehicleData.isValid {
                Text("myVehicle.capacity.invalid".translated)
                    .foregroundStyle(.red)
            } else {
                Text("myVehicle.section.tank.hint".translated)
            }
        }
    }
    
    @ViewBuilder
    var actionsSection: some View {
        Section {
            Button {
                focusedField = nil
                viewModel.save()
                onSave?()
            } label: {
                Text("myVehicle.save".translated)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .foregroundStyle(.background)
            .foregroundStyle(.background)
            .buttonWidth()
            .disabled(!viewModel.vehicleData.isValid)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        
        if viewModel.isSaved {
            Section {
                Button(role: .destructive) {
                    showRemoveVehicleAlert = true
                } label: {
                    Text("myVehicle.remove".translated)
                        .frame(maxWidth: .infinity)
                }
            }
            .tightSectionSpacing()
        }
    }
}

private struct PromptField: View {
    
    let prompt: String
    @Binding var text: String
    
    var body: some View {
        TextField("", text: $text, prompt: Text(prompt))
            .labelsHidden()
            .multilineTextAlignment(.trailing)
#if os(macOS)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)
#endif
    }
}

private struct LabeledRow<Content: View>: View {
    
    let icon: String
    let title: String
    @ViewBuilder var content: Content
    
    var body: some View {
        LabeledContent {
            content
#if os(iOS)
                .multilineTextAlignment(.trailing)
#endif
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
        }
    }
}

private extension View {
    
    @ViewBuilder
    func platformFormStyle() -> some View {
#if os(macOS)
        formStyle(.grouped)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
#else
        self
#endif
    }
    
    @ViewBuilder
    func buttonWidth() -> some View {
#if os(macOS)
        frame(maxWidth: .infinity)
#else
        frame(maxWidth: 420)
#endif
    }
    
    @ViewBuilder
    func tightSectionSpacing() -> some View {
#if os(iOS)
        listSectionSpacing(12)
#else
        self
#endif
    }
}

extension Double {
    
    var asEuros: String {
        String(format: "%.2f", self).replacingOccurrences(of: ".", with: ",") + " €"
    }
}

#Preview {
    VehicleView(stationsViewModel: StationsListViewViewModel())
}
