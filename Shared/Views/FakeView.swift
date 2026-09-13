//
//  FakeView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 21/4/22.
//

import SwiftUI
import Shimmer

struct FakeView: View {
    
    private let fill = Color.primary.opacity(0.13)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 15)
                .fill(fill)
                .frame(height: 70)
            HStack(spacing: 10) {
                Circle()
                    .fill(fill)
                    .frame(width: 30, height: 30)
                bar(width: 110, height: 18)
                Spacer(minLength: 20)
                bar(width: 64, height: 14)
            }
            bar(width: 190, height: 13)
            bar(width: 130, height: 11)
            RoundedRectangle(cornerRadius: 12)
                .fill(fill)
                .frame(height: 40)
        }
        .padding(.vertical, 15)
        .shimmering()
    }
    
    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(fill)
            .frame(width: width, height: height)
    }
}

struct FakeView_Previews: PreviewProvider {
    static var previews: some View {
        FakeView().padding()
    }
}
