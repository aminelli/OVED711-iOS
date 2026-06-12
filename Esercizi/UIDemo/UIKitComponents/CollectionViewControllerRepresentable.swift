//
//  CollectionViewControllerRepresentable.swift
//  UIDemo
//
//  Esempio di UIViewControllerRepresentable: UICollectionViewController
//  con Compositional Layout (introdotto in iOS 13).
//
//  UIViewControllerRepresentable è il ponte per integrare un intero
//  UIViewController nel mondo SwiftUI. Il Coordinator funge da
//  UICollectionViewDelegate e UICollectionViewDataSource.
//
//  Questo esempio mostra un layout a griglia mista (featured + grid)
//  usando NSCollectionLayoutSection con sezioni distinte.
//

import SwiftUI
import UIKit

// MARK: - CollectionViewControllerRepresentable

/// Wrapper SwiftUI per un UICollectionViewController con layout composizionale.
/// Accetta un array di DemoItem e li visualizza in un layout a griglia mista.
struct CollectionViewControllerRepresentable: UIViewControllerRepresentable {

    let items: [DemoItem]
    /// Callback quando l'utente seleziona un item
    var onSelect: (DemoItem) -> Void

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> UICollectionViewController {
        // Costruisce il layout composizionale con due sezioni distinte
        let layout = makeCompositionalLayout()
        let controller = UICollectionViewController(collectionViewLayout: layout)

        // Registra le celle riutilizzabili
        controller.collectionView.register(
            DemoItemCell.self,
            forCellWithReuseIdentifier: DemoItemCell.reuseID
        )
        controller.collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.reuseID
        )

        controller.collectionView.dataSource = context.coordinator
        controller.collectionView.delegate = context.coordinator
        controller.collectionView.backgroundColor = .systemBackground

        // Aggiunge effetto bounce verticale per un feel nativo
        controller.collectionView.alwaysBounceVertical = true

        return controller
    }

    func updateUIViewController(_ controller: UICollectionViewController, context: Context) {
        // Aggiorna il coordinator con i nuovi dati e ricarica la collezione
        context.coordinator.items = items
        context.coordinator.onSelect = onSelect
        controller.collectionView.reloadData()
    }

    // MARK: - Compositional Layout

    /// Costruisce un NSCollectionViewCompositionalLayout con due sezioni:
    /// - Sezione 0: item "featured" a larghezza piena (banner)
    /// - Sezione 1: griglia 2 colonne
    private func makeCompositionalLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0:
                return Self.makeFeaturedSection()
            default:
                return Self.makeGridSection()
            }
        }
    }

    /// Sezione "featured": item singolo a larghezza piena, altezza fissa 180pt.
    private static func makeFeaturedSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(180)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(196)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)

        // Header della sezione
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Sezione griglia: 2 colonne di item quadrati.
    private static func makeGridSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.5) // Quadrato
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.5)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {

        var items: [DemoItem]
        var onSelect: (DemoItem) -> Void

        init(items: [DemoItem], onSelect: @escaping (DemoItem) -> Void) {
            self.items = items
            self.onSelect = onSelect
        }

        // MARK: - DataSource

        func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            section == 0 ? min(1, items.count) : max(0, items.count - 1)
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: DemoItemCell.reuseID,
                for: indexPath
            ) as! DemoItemCell

            let itemIndex = indexPath.section == 0 ? 0 : indexPath.item + 1
            guard itemIndex < items.count else { return cell }
            cell.configure(with: items[itemIndex], isFeatured: indexPath.section == 0)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseID,
                for: indexPath
            ) as! SectionHeaderView
            header.title = indexPath.section == 0 ? "In Evidenza" : "Tutti gli elementi"
            return header
        }

        // MARK: - Delegate
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let itemIndex = indexPath.section == 0 ? 0 : indexPath.item + 1
            guard itemIndex < items.count else { return }
            onSelect(items[itemIndex])
        }
    }
}

// MARK: - DemoItemCell

/// Cella UIKit con programmatic Auto Layout.
final class DemoItemCell: UICollectionViewCell {
    static let reuseID = "DemoItemCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func configure(with item: DemoItem, isFeatured: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: isFeatured ? 40 : 24, weight: .medium)
        iconView.image = UIImage(systemName: item.iconName, withConfiguration: config)
        iconView.tintColor = UIColor(item.swiftUIColor)
        titleLabel.text = item.title
        titleLabel.font = isFeatured
            ? UIFont.systemFont(ofSize: 20, weight: .bold)
            : UIFont.systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = !isFeatured
        contentView.backgroundColor = UIColor(item.swiftUIColor).withAlphaComponent(0.1)
    }

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        [iconView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])

        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
    }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UICollectionReusableView {
    static let reuseID = "SectionHeaderView"

    private let label = UILabel()

    var title: String = "" {
        didSet { label.text = title }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("Not used") }
}
