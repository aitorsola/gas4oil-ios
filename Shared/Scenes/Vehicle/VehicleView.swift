//
//  VehicleView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 21/3/22.
//

import SwiftUI

struct VehicleView: View {
    
    /// Read-only: the screen uses the loaded stations to price a tankful.
    let stationsViewModel: StationsListViewViewModel
    /// Lets the stations list pick up the new capacity without waiting for a reload.
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

// MARK: - Payoff

private extension VehicleView {
    
    /// The screen used to be a form that gave nothing back: you typed a tank size and the result
    /// only ever appeared on the stations tab. This puts the answer where the question is asked.
    @ViewBuilder
    var fillCostSection: some View {
        Section {
            if let cost = viewModel.fillCost(using: stationsViewModel.stations) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("myVehicle.fill.title".translated)
                        .font(.customSize(13))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(cost.cheapest.asEuros)
                            .font(.customSize(32, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("—")
                            .foregroundStyle(.secondary)
                        Text(cost.priciest.asEuros)
                            .font(.customSize(22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("myVehicle.fill.cheapestAt".translated(cost.cheapestStation.brandName,
                                                               cost.cheapestStation.municipio.capitalized))
                        .font(.customSize(13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
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
                    .foregroundStyle(.orange)
                Text("myVehicle.ad.description".translated)
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Form

private extension VehicleView {
    
    var vehicleSection: some View {
        Section {
            LabeledRow(icon: "tag.fill", title: "myVehicle.brand.placeholder".translated) {
                TextField("myVehicle.brand.example".translated, text: $viewModel.vehicleData.brand)
                    .focused($focusedField, equals: .brand)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .model }
            }
            LabeledRow(icon: "car.fill", title: "myVehicle.model.placeholder".translated) {
                TextField("myVehicle.model.example".translated, text: $viewModel.vehicleData.model)
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
                    TextField("myVehicle.capacity.example".translated,
                              text: $viewModel.vehicleData.capacity)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                        .focused($focusedField, equals: .capacity)
                        .multilineTextAlignment(.trailing)
                    Text("myVehicle.capacity.unit".translated)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("myVehicle.section.tank".translated)
        } footer: {
            // Only flag the problem once they have typed something; an empty field is not an error.
            if !viewModel.vehicleData.capacity.isEmpty && !viewModel.vehicleData.isValid {
                Text("myVehicle.capacity.invalid".translated)
                    .foregroundStyle(.red)
            } else {
                Text("myVehicle.section.tank.hint".translated)
            }
        }
    }
    
    /// Save and Remove live in separate sections on purpose: sharing a card gave them equal
    /// weight, and the row separator between them was inset to wherever the centred label began,
    /// because that is where iOS measures a row's content from.
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
            .tint(.orange)
            .frame(maxWidth: 420)
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
            // Default section spacing left the two actions a screen apart; they are related
            // enough to sit together, just not in the same card.
            .tightSectionSpacing()
        }
    }
}

/// Native label/content row. A hand-rolled `HStack` here fought the macOS form's own label
/// column, which pushed the labels outside the window.
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
    
    /// macOS forms need the grouped style to get the card look, and a width cap so the rows do
    /// not run the whole width of a desktop window.
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
    
    /// `listSectionSpacing` is unavailable on macOS, where the default gap is already small.
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
