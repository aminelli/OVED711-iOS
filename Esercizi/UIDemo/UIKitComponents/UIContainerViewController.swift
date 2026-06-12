//
//  UIContainerViewController.swift
//  UIDemo
//
//  Created by Antonio Minelli on 12/06/2026.
//


import UIKit
import SwiftUI

final class UIContainerViewController: UIViewController {
    
    private let hostingController: UIHostingController<SwiftUIGuestView>

    init(){
        self.hostingController = UIHostingController(rootView: SwiftUIGuestView())
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        // hostingController.view.frame(height: 120)
        //    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    func update(){
        hostingController.rootView = SwiftUIGuestView()
    }
    
}

public struct SwiftUIGuestView: View {
    @State private var count = 0

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("SwiftUI in UIKit")
                    .font(AppTheme.Typography.headline)
                Text("Questa view vive in un UIHostingController")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
            // Bottone con @State locale: funziona normalmente anche se ospitato in UIKit
            Button {
                withAnimation(AppTheme.Animation.bouncy) { count += 1 }
            } label: {
                Text("\(count)")
                    .font(AppTheme.Typography.title2)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .contentTransition(.numericText())
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.primary.opacity(0.08))
    }
}


struct ContainerRapresentable: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UIContainerViewController {
        UIContainerViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIContainerViewController, context: Context) {
        uiViewController.update()
    }
}
 
