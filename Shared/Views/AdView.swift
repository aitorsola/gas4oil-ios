//
//  AdView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 5/4/22.
//

import SwiftUI

struct OnboardingTip: Identifiable {
    let symbol: String
    let title: String
    let detail: String
    
    var id: String { symbol }
}

struct AdView: View {
    
    let title: String
    let tips: [OnboardingTip]
    let buttonTitle: String
    let buttonHandler: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.customSize(26, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 32)
                .padding(.horizontal, 24)
            VStack(alignment: .leading, spacing: 22) {
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: tip.symbol)
                            .font(.customSize(20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tip.title)
                                .font(.customSize(16, weight: .semibold))
                            Text(tip.detail)
                                .font(.customSize(14))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            Spacer(minLength: 24)
            Button {
                buttonHandler?()
            } label: {
                Text(buttonTitle)
                    .font(.customSize(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .invertedForeground()
            }
            .primaryButtonStyle()
            .controlSize(.large)
            .tint(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}

struct AdView_Previews: PreviewProvider {
    static var previews: some View {
        AdView(title: "¿Qué puedes hacer?",
               tips: [OnboardingTip(symbol: "arrow.up.arrow.down",
                                    title: "Ordena como quieras",
                                    detail: "Por cercanía o por precio."),
                      OnboardingTip(symbol: "fuelpump",
                                    title: "Filtra por marca",
                                    detail: "Y por el combustible que usas.")],
               buttonTitle: "Empezar") { }
    }
}
