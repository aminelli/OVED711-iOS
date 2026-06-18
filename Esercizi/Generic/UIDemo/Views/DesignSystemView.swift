//
//  DesignSystemView.swift
//  UIDemo
//
//  Showcase del design system dell'applicazione:
//  - Palette colori semantici e primitivi
//  - Scala tipografica (Dynamic Type categories)
//  - Scala di spaziatura (4pt base unit)
//  - Componenti e varianti
//  - Animazioni preset
//
//  Questo tipo di schermata è comune nei design systems per
//  documentare e testare i token visivi dell'applicazione.
//

import SwiftUI

// MARK: - DesignSystemView

struct DesignSystemView: View {

    @Environment(\.appTheme) private var theme
    @State private var selectedSection: DSSection = .colors
    @State private var animateDemo: Bool = false
    @State private var selectedAnimation: AnimationPreset = .standard

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {

                // Segmented control sezioni
                Picker("Sezione", selection: $selectedSection) {
                    ForEach(DSSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.md)

                Group {
                    switch selectedSection {
                    case .colors:     colorsSection
                    case .typography: typographySection
                    case .spacing:    spacingSection
                    case .components: componentsSection
                    case .animations: animationsSection
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .animation(AppTheme.Animation.standard, value: selectedSection)
            }
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sezione Colori

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {

            colorGroup(title: "Colori Semantici", items: [
                ("Primary",    AppTheme.Colors.primary),
                ("Secondary",  AppTheme.Colors.secondary),
                ("Accent",     AppTheme.Colors.accent),
                ("Success",    AppTheme.Colors.success),
                ("Warning",    AppTheme.Colors.warning),
                ("Error",      AppTheme.Colors.error),
            ])

            colorGroup(title: "Sfondi", items: [
                ("Background",          AppTheme.Colors.background),
                ("Secondary BG",        AppTheme.Colors.secondaryBackground),
                ("Surface",             AppTheme.Colors.surface),
            ])

            colorGroup(title: "Testo", items: [
                ("Text Primary",    AppTheme.Colors.textPrimary),
                ("Text Secondary",  AppTheme.Colors.textSecondary),
                ("Text Tertiary",   AppTheme.Colors.textTertiary),
                ("Separator",       AppTheme.Colors.separator),
            ])
        }
    }

    private func colorGroup(title: String, items: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(items, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(color)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        Text(name)
                            .font(AppTheme.Typography.caption2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Colore \(name)")
                }
            }
        }
    }

    // MARK: - Sezione Tipografia

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Scala tipografica")
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            VStack(spacing: 0) {
                ForEach(typographyItems, id: \.name) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(AppTheme.Typography.caption2)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                            .frame(width: 90, alignment: .leading)

                        Text(item.sample)
                            .font(item.font)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)

                    if item.name != typographyItems.last?.name {
                        Divider()
                    }
                }
            }
            .cardStyle()
        }
    }

    private var typographyItems: [(name: String, sample: String, font: Font)] {[
        ("largeTitle",  "Large Title",  AppTheme.Typography.largeTitle),
        ("title",       "Title",        AppTheme.Typography.title),
        ("title2",      "Title 2",      AppTheme.Typography.title2),
        ("title3",      "Title 3",      AppTheme.Typography.title3),
        ("headline",    "Headline",     AppTheme.Typography.headline),
        ("body",        "Body text",    AppTheme.Typography.body),
        ("callout",     "Callout",      AppTheme.Typography.callout),
        ("subheadline", "Subheadline",  AppTheme.Typography.subheadline),
        ("footnote",    "Footnote",     AppTheme.Typography.footnote),
        ("caption",     "Caption",      AppTheme.Typography.caption),
        ("caption2",    "Caption 2",    AppTheme.Typography.caption2),
        ("code",        "func hello()", AppTheme.Typography.code),
    ]}

    // MARK: - Sezione Spaziatura

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Scala di spaziatura (base 4pt)")
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(spacingItems, id: \.name) { item in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Text(item.name)
                            .font(AppTheme.Typography.code)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 60, alignment: .leading)

                        Text("\(Int(item.value))pt")
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36)

                        // Barra visiva proporzionale
                        Rectangle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: item.value, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()
                    }
                }
            }
            .cardStyle()

            Text("Utilizza sempre i token di spaziatura invece di valori arbitrari.")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .italic()
        }
    }

    private var spacingItems: [(name: String, value: CGFloat)] {[
        ("xxs",  AppTheme.Spacing.xxs),
        ("xs",   AppTheme.Spacing.xs),
        ("sm",   AppTheme.Spacing.sm),
        ("md",   AppTheme.Spacing.md),
        ("lg",   AppTheme.Spacing.lg),
        ("xl",   AppTheme.Spacing.xl),
        ("xxl",  AppTheme.Spacing.xxl),
    ]}

    // MARK: - Sezione Componenti

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {

            // Bottoni
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Bottoni")
                    .font(AppTheme.Typography.title3)
                    .sectionHeader()

                VStack(spacing: AppTheme.Spacing.sm) {
                    Button("Primary Button") {}
                        .buttonStyle(PrimaryButtonStyle())

                    Button("Secondary Button") {}
                        .buttonStyle(SecondaryButtonStyle())

                    Button("Glass Button") {}
                        .buttonStyle(LiquidGlassCapsuleButtonStyle())
                        .padding()
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                }
            }

            // Corner Radius
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Border Radius")
                    .font(AppTheme.Typography.title3)
                    .sectionHeader()

                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(cornerRadiusItems, id: \.name) { item in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(AppTheme.Colors.primary.opacity(0.2))
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: item.value))
                                .overlay(
                                    RoundedRectangle(cornerRadius: item.value)
                                        .strokeBorder(AppTheme.Colors.primary, lineWidth: 1.5)
                                )

                            Text(item.name)
                                .font(AppTheme.Typography.caption2)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }

            // Badge / Chip
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Badge e Chip")
                    .font(AppTheme.Typography.title3)
                    .sectionHeader()

                FlowLayout(spacing: AppTheme.Spacing.xs) {
                    ForEach(["SwiftUI", "UIKit", "iOS 26", "LiquidGlass", "Swift 6.3", "Accessibility"], id: \.self) { tag in
                        Text(tag)
                            .font(AppTheme.Typography.caption)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 5)
                            .background(AppTheme.Colors.primary.opacity(0.12))
                            .foregroundStyle(AppTheme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var cornerRadiusItems: [(name: String, value: CGFloat)] {[
        ("small",  AppTheme.CornerRadius.small),
        ("medium", AppTheme.CornerRadius.medium),
        ("large",  AppTheme.CornerRadius.large),
        ("xLarge", AppTheme.CornerRadius.xLarge),
    ]}

    // MARK: - Sezione Animazioni

    private var animationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Preset animazioni")
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            // Picker preset animazione
            Picker("Animazione", selection: $selectedAnimation) {
                ForEach(AnimationPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            // Demo animazione
            VStack(spacing: AppTheme.Spacing.md) {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(AppTheme.Colors.primary)
                    .frame(width: animateDemo ? 240 : 80, height: 60)
                    .animation(selectedAnimation.animation, value: animateDemo)

                Button(animateDemo ? "Reset" : "Anima") {
                    animateDemo.toggle()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

            // Descrizione preset
            ForEach(AnimationPreset.allCases) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.title)
                            .font(AppTheme.Typography.subheadline)
                            .bold()
                        Text(preset.description)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if selectedAnimation == preset {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                }
                .padding(AppTheme.Spacing.sm)
                .background(selectedAnimation == preset
                    ? AppTheme.Colors.primary.opacity(0.08)
                    : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                .onTapGesture {
                    withAnimation(AppTheme.Animation.fast) {
                        selectedAnimation = preset
                        animateDemo = false
                    }
                }
            }
        }
    }
}

// MARK: - DSSection Enum

private enum DSSection: String, CaseIterable, Identifiable {
    case colors, typography, spacing, components, animations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colors:     return "Colori"
        case .typography: return "Tipo"
        case .spacing:    return "Spazio"
        case .components: return "Comp."
        case .animations: return "Anim."
        }
    }
}

// MARK: - AnimationPreset Enum

private enum AnimationPreset: String, CaseIterable, Identifiable {
    case fast, standard, slow, bouncy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:     return "Fast"
        case .standard: return "Standard"
        case .slow:     return "Slow"
        case .bouncy:   return "Bouncy"
        }
    }

    var description: String {
        switch self {
        case .fast:     return "Feedback immediato (pulsanti, toggle). response: 0.25s"
        case .standard: return "Transizioni UI standard. response: 0.4s"
        case .slow:     return "Apertura modal e pannelli. response: 0.6s"
        case .bouncy:   return "Elementi celebrativi. damping: 0.6"
        }
    }

    var animation: Animation {
        switch self {
        case .fast:     return AppTheme.Animation.fast
        case .standard: return AppTheme.Animation.standard
        case .slow:     return AppTheme.Animation.slow
        case .bouncy:   return AppTheme.Animation.bouncy
        }
    }
}

// MARK: - FlowLayout (layout a flusso per i chip/tag)

/// Layout che posiziona le view in righe, andando a capo automaticamente.
/// Utile per tag, chip e badge di lunghezza variabile.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth && !rows.last!.isEmpty {
                rows.append([subview])
                currentRowWidth = size.width + spacing
            } else {
                rows[rows.count - 1].append(subview)
                currentRowWidth += size.width + spacing
            }
        }

        let totalHeight = rows.reduce(CGFloat(0)) { sum, row in
            sum + (row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0) + spacing
        }
        return CGSize(width: maxWidth, height: totalHeight - spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentRowWidth: CGFloat = 0
        let maxWidth = bounds.width

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth && !rows.last!.isEmpty {
                rows.append([subview])
                currentRowWidth = size.width + spacing
            } else {
                rows[rows.count - 1].append(subview)
                currentRowWidth += size.width + spacing
            }
        }

        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}

#Preview {
    NavigationStack {
        DesignSystemView()
    }
    .environment(AppState())
}
