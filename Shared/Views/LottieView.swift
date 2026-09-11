//
//  LottieView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 19/3/22.
//

import SwiftUI
import Lottie

/// Named after the type it wraps rather than `LottieView`, which is also the name of the SwiftUI
/// view Lottie 4 ships.
struct LottieAnimationRepresentable: UIViewRepresentable {
    
    var name: String
    var loopMode: LottieLoopMode = .playOnce
    
    func makeUIView(context: UIViewRepresentableContext<LottieAnimationRepresentable>) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView(animation: LottieAnimation.named(name))
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<LottieAnimationRepresentable>) {
        
    }
}
