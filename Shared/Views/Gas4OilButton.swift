//
//  Gas4OilButton.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 6/3/22.
//

import SwiftUI

struct Gas4OilButton: View {
    
    let title: String
    let image: Image?
    var isDisabled: Bool
    let completion: (() -> Void)?
    
    @State var needsRotate: Bool = false
    
    var body: some View {
        HStack {
            if let image = image {
                image
                    .frame(width: 20, height: 20)
                    .foregroundColor(.orange)
                    .rotationEffect(Angle.degrees(needsRotate ? 360 : 0))
            }
            Text(title.uppercased())
                .multilineTextAlignment(.center)
                .foregroundColor(isDisabled ? .gray : .orange)
                .font(.system(size: 20, weight: .medium, design: .default))
                .font(.customSize(20, weight: .medium, design: .rounded))
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(isDisabled ? .gray : .orange, lineWidth: 2))
        .onTapGesture {
            guard !isDisabled else {
                return
            }
            withAnimation(.easeInOut(duration: 1)) {
                needsRotate.toggle()
            }
            completion?()
        }
    }
}

struct Gas4OilButton_Previews: PreviewProvider {
    static var previews: some View {
        Gas4OilButton(title: "Hola", image: Image(systemName: "location"), isDisabled: false, completion: nil)
    }
}
