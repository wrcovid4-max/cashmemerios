import CoreData
import PhotosUI
import SwiftUI

struct NewReceiptView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appLanguage) private var language

    @StateObject private var draft = ReceiptDraft()
    @StateObject private var scanner = ScannerCoordinator()
    @State private var isPresentingMembers = false
    @State private var isPresentingGallery = false
    @State private var isPresentingCamera = false
    @State private var isPresentingBarcode = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var generated: CDReceipt?
    @State private var isShowingGenerated = false
    @State private var errorMessage: String?
    @State private var isLocating = false

    private let locationService = LocationService()

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 0) {
                    formColumn
                    Divider()
                    previewColumn
                }
            } else {
                formColumn
            }
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.appName, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: seedDraft)
        .sheet(isPresented: $isPresentingMembers) {
            MemberPickerSheet { member in
                draft.apply(member)
            }
        }
        .sheet(isPresented: $isPresentingCamera) {
            CameraPicker { data in Task { await runScan(on: data, source: "Camera") } }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingBarcode) {
            BarcodeScannerSheet { code in
                draft.addLine(name: code, quantity: 1, unitPrice: 0)
            }
        }
        .photosPicker(isPresented: $isPresentingGallery, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await runScan(on: data)
                }
                photoSelection = nil
            }
        }
        .navigationDestination(isPresented: $isShowingGenerated) {
            if let generated = generated {
                ReceiptDetailView(receipt: generated)
            }
        }
        .alert(
            L10n.string(.aiReceiptScanner, language: language),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(L10n.string(.ok, language: language), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Columns

    private var formColumn: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                CloudSyncCard()
                scannerSection
                detailsSection
                AddItemsSection(draft: draft)
                discountSection
                notesSection
                SignaturePadView(
                    signaturePNG: $draft.signaturePNG,
                    saveAsDefault: $draft.saveSignatureAsDefault
                )
                actionButtons

                // On iPhone there is no side-by-side pane, so the memo preview
                // lives inline at the bottom of the form instead.
                if sizeClass != .regular {
                    inlinePreview
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: sizeClass == .regular ? 520 : .infinity)
        .scrollDismissesKeyboard(.interactively)
    }

    private var previewColumn: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(L10n.string(.livePreview, language: language))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    ForEach(CashMemoView.Page.allCases) { page in
                        CashMemoView(memo: draft.snapshot, style: .preview, page: page)
                            .frame(maxWidth: 460)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    }
                }
                .padding(Theme.Spacing.l)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.l)
    }

    private var inlinePreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(L10n.string(.livePreview, language: language)).sectionCaption()
            ForEach(CashMemoView.Page.allCases) { page in
                CashMemoView(memo: draft.snapshot, style: .preview, page: page)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.separator, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Sections

    private var scannerSection: some View {
        FormSection(titleKey: .aiReceiptScanner) {
            VStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    SoftActionButton(titleKey: .gallery, systemImage: "photo.on.rectangle") {
                        isPresentingGallery = true
                    }
                    SoftActionButton(titleKey: .camera, systemImage: "camera") {
                        isPresentingCamera = true
                    }
                }
                SoftActionButton(titleKey: .scanBarcode, systemImage: "barcode.viewfinder") {
                    isPresentingBarcode = true
                }

                if scanner.isScanning {
                    HStack(spacing: Theme.Spacing.s) {
                        ProgressView()
                        Text(L10n.string(.aiReceiptScanner, language: language))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                NavigationLink {
                    HistoryView()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(L10n.string(.viewScanHistory, language: language))
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(Theme.brand)
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    private var detailsSection: some View {
        FormSection(titleKey: .receiptDetails) {
            FormFieldRow(placeholderKey: .titleField, text: $draft.title)
            FormFieldRow(placeholderKey: .placeStoreName, text: $draft.storeName)
            FormFieldRow(
                placeholderKey: .address,
                text: $draft.address,
                trailing: AnyView(locationButtons)
            )
            FormPickerRow(
                titleKey: .currency,
                selection: $draft.currency,
                options: settings.availableCurrencies
            ) { currency in
                Text(currency.pickerLabel)
            }
            FormPickerRow(
                titleKey: .category,
                selection: $draft.category,
                options: ReceiptCategory.allCases
            ) { category in
                Label(
                    L10n.string(category.key, language: language),
                    systemImage: category.systemImage
                )
            }
            FormPickerRow(
                titleKey: .paymentType,
                selection: $draft.paymentMethod,
                options: PaymentMethod.allCases
            ) { method in
                Label(
                    L10n.string(method.key, language: language),
                    systemImage: method.systemImage
                )
            }

            Button {
                isPresentingMembers = true
            } label: {
                HStack {
                    Label(
                        L10n.string(.selectMember, language: language),
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                    .foregroundStyle(Theme.brand)
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, Theme.Spacing.l)

            FormFieldRow(placeholderKey: .customerName, text: $draft.customerName)
            FormFieldRow(placeholderKey: .customerPhone, text: $draft.customerPhone, keyboard: .phonePad)
            FormFieldRow(
                placeholderKey: .customerEmail,
                text: $draft.customerEmail,
                keyboard: .emailAddress
            )
            FormFieldRow(
                placeholderKey: .customerAddress,
                text: $draft.customerAddress,
                showsDivider: false
            )
        }
    }

    private var locationButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            if draft.latitude != nil {
                Image(systemName: "map.fill")
                    .foregroundStyle(Theme.brand)
            }
            Button(action: captureLocation) {
                Group {
                    if isLocating {
                        ProgressView()
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .foregroundStyle(Theme.brand)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.locationAddressGPS, language: language))
        }
    }

    private var discountSection: some View {
        FormSection(titleKey: .discountAndTax) {
            FormPickerRow(
                titleKey: .discountType,
                selection: $draft.discountType,
                options: DiscountType.allCases
            ) { type in
                Text(L10n.string(type.key, language: language))
            }
            if draft.discountType != .none {
                FormFieldRow(
                    placeholderKey: draft.discountType == .percentage ? .discountPercentage : .discountFixed,
                    text: $draft.discountValueText,
                    keyboard: .decimalPad
                )
            }
            FormFieldRow(
                placeholderKey: .taxPercentOptional,
                text: $draft.taxPercentText,
                keyboard: .decimalPad
            )
            FormFieldRow(
                placeholderKey: .cashGiven,
                text: $draft.cashGivenText,
                keyboard: .decimalPad,
                showsDivider: false
            )
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            FormSection(titleKey: .notes) {
                FormFieldRow(placeholderKey: .note, text: $draft.note)
                FormFieldRow(placeholderKey: .notesPageTwo, text: $draft.notesPageTwo, showsDivider: false)
            }
            Text(L10n.string(.noteTwoPrivateHint, language: language))
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            SubtleDestructiveButton(titleKey: .clear, systemImage: "line.3.horizontal") {
                draft.reset(
                    defaultCurrency: settings.defaultCurrency,
                    defaultSignature: settings.defaultSignaturePNG,
                    nextNumber: CDReceipt.nextNumber(in: context)
                )
                draft.adoptIssuer(from: settings)
            }
            .frame(maxWidth: .infinity)

            PrimaryButton(
                titleKey: .generate,
                systemImage: "checkmark",
                isEnabled: draft.canGenerate,
                action: generate
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func seedDraft() {
        if draft.lines.isEmpty && draft.storeName.isEmpty {
            draft.currency = settings.defaultCurrency
            draft.signaturePNG = settings.defaultSignaturePNG
        }
        draft.adoptIssuer(from: settings)
        if draft.lines.isEmpty {
            draft.number = CDReceipt.nextNumber(in: context)
        }
    }

    private func captureLocation() {
        isLocating = true
        Task {
            defer { isLocating = false }
            guard let location = await locationService.currentLocation() else { return }
            draft.latitude = location.coordinate.latitude
            draft.longitude = location.coordinate.longitude
            if let address = await locationService.address(for: location) {
                draft.address = address
            }
        }
    }

    private func runScan(on imageData: Data, source: String = "Gallery") async {
        do {
            let result = try await scanner.scan(
                imageData: imageData,
                source: source,
                currencySymbol: draft.currency.symbol
            )
            draft.apply(result, settings: settings)
            settings.recordScan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generate() {
        do {
            let receipt = try draft.persist(in: context)
            if draft.saveSignatureAsDefault, let signature = draft.signaturePNG {
                settings.defaultSignaturePNG = signature
            }
            draft.reset(
                defaultCurrency: settings.defaultCurrency,
                defaultSignature: settings.defaultSignaturePNG,
                nextNumber: CDReceipt.nextNumber(in: context)
            )
            draft.adoptIssuer(from: settings)
            generated = receipt
            isShowingGenerated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Picks the best available scanner, tracks in-flight state for the spinner, and
/// mirrors progress into the Live Activity so the result reaches the Lock Screen.
@MainActor
final class ScannerCoordinator: ObservableObject {
    @Published private(set) var isScanning = false

    func scan(imageData: Data, source: String, currencySymbol: String) async throws -> ScannedReceipt {
        isScanning = true
        ScanActivityController.shared.start(source: source, currencySymbol: currencySymbol)
        defer { isScanning = false }

        do {
            ScanActivityController.shared.update(phase: .uploading)

            // Prefer Gemini when a key is configured; otherwise fall back to on-device
            // Vision so the button still does something useful.
            let scanner: ReceiptScanning = GeminiReceiptScanner.apiKey?.isEmpty == false
                ? GeminiReceiptScanner()
                : VisionReceiptScanner()

            ScanActivityController.shared.update(phase: .parsing)
            let result = try await scanner.scan(imageData: imageData)

            ScanActivityController.shared.finish(
                storeName: result.storeName,
                itemsFound: result.lines.count,
                total: result.total
            )
            return result
        } catch {
            ScanActivityController.shared.finish(
                storeName: nil, itemsFound: 0, total: nil, failed: true
            )
            throw error
        }
    }
}
