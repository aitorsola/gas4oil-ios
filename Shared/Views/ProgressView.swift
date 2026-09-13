//
//  ProgressView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 3/3/22.
//

import SwiftUI

struct ProgressView: View {
    
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            SwiftUI.ProgressView()
            Text(title).font(.customSize(20))
        }
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView(title: "common.loading".translated)
            .preferredColorScheme(.dark)
    }
}
