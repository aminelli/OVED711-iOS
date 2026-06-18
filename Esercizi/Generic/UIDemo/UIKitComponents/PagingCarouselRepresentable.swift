//
//  PagingCarouselRepresentable.swift
//  UIDemo
//
//  Esempio di UIViewRepresentable: avvolge UIScrollView con paginazione
//  in una view SwiftUI riutilizzabile.
//
//  Problema comune: updateUIView viene chiamato PRIMA che lo UIScrollView
//  abbia ricevuto il suo frame definitivo da Auto Layout. Di conseguenza
//  scrollView.bounds.width vale 0 e le pagine vengono create a larghezza zero.
//
//  Soluzione: usare una sottoclasse PagingScrollView che sovrascrive
//  layoutSubviews(). Questo metodo viene chiamato DOPO che il sistema
//  ha assegnato il frame corretto, garantendo che bounds.width sia valido.
//

import SwiftUI
import UIKit

// MARK: - PagingScrollView (sottoclasse UIScrollView)

/// UIScrollView paginato che posiziona le proprie pagine in layoutSubviews,
/// ovvero dopo che Auto Layout ha risolto le dimensioni definitive.
final class PagingScrollView: UIScrollView {

    var pages: [CarouselPage] = [] {
        didSet { setNeedsLayout() }
    }

    var onPageChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        bounces = true
        delegate = self
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let pageWidth  = bounds.width
        let pageHeight = bounds.height
        guard pageWidth > 0, pageHeight > 0 else { return }

        subviews.forEach { $0.removeFromSuperview() }

        for (index, page) in pages.enumerated() {
            addSubview(buildPageView(page: page, index: index,
                                    pageWidth: pageWidth, pageHeight: pageHeight))
        }

        contentSize = CGSize(width: pageWidth * CGFloat(pages.count), height: pageHeight)
    }

    private func buildPageView(page: CarouselPage, index: Int,
                               pageWidth: CGFloat, pageHeight: CGFloat) -> UIView {
        let view = UIView(frame: CGRect(x: CGFloat(index) * pageWidth, y: 0,
                                       width: pageWidth, height: pageHeight))
        view.backgroundColor = page.color.withAlphaComponent(0.15)

        let card = UIView(frame: CGRect(x: 24, y: 32,
                                       width: pageWidth - 48, height: pageHeight - 64))
        card.backgroundColor = page.color.withAlphaComponent(0.3)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        view.addSubview(card)

        let imageConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        let imageView = UIImageView(image: UIImage(systemName: page.iconName,
                                                   withConfiguration: imageConfig))
        imageView.tintColor = page.color
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(imageView)

        let label = UILabel()
        label.text = page.title
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = page.color
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        let subtitle = UILabel()
        subtitle.text = page.subtitle
        subtitle.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitle.textColor = page.color.withAlphaComponent(0.8)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 2
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subtitle)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -50),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),

            subtitle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            subtitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        return view
    }
}

// MARK: - UIScrollViewDelegate

extension PagingScrollView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        onPageChanged?(page)
    }
}

// MARK: - Coordinator

final class PagingCarouselCoordinator: NSObject {
    var onPageChanged: (Int) -> Void

    init(onPageChanged: @escaping (Int) -> Void) {
        self.onPageChanged = onPageChanged
    }
}

// MARK: - PagingCarouselRepresentable

struct PagingCarouselRepresentable: UIViewRepresentable {

    let pages: [CarouselPage]
    @Binding var currentPage: Int

    func makeCoordinator() -> PagingCarouselCoordinator {
        PagingCarouselCoordinator { newPage in
            currentPage = newPage
        }
    }

    func makeUIView(context: Context) -> PagingScrollView {
        let scrollView = PagingScrollView()
        scrollView.onPageChanged = { [coordinator = context.coordinator] page in
            coordinator.onPageChanged(page)
        }
        scrollView.accessibilityLabel = "Carosello di \(pages.count) pagine"
        return scrollView
    }

    func updateUIView(_ scrollView: PagingScrollView, context: Context) {
        scrollView.pages = pages

        context.coordinator.onPageChanged = { newPage in
            currentPage = newPage
        }
        scrollView.onPageChanged = { [coordinator = context.coordinator] page in
            coordinator.onPageChanged(page)
        }

        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let targetOffsetX = pageWidth * CGFloat(currentPage)
        if scrollView.contentOffset.x != targetOffsetX {
            scrollView.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: true)
        }
    }
}

// MARK: - CarouselPage Model

struct CarouselPage: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var iconName: String
    var color: UIColor

    static let samples: [CarouselPage] = [
        CarouselPage(title: "SwiftUI",       subtitle: "Il futuro delle UI Apple", iconName: "swift",              color: .systemOrange),
        CarouselPage(title: "UIKit",         subtitle: "Potenza e flessibilita",   iconName: "uiwindow.split.2x1", color: .systemBlue),
        CarouselPage(title: "LiquidGlass",   subtitle: "iOS 26 Design Language",   iconName: "drop.fill",          color: .systemTeal),
        CarouselPage(title: "Accessibility", subtitle: "Inclusivita by design",    iconName: "accessibility",      color: .systemPurple),
    ]
}
