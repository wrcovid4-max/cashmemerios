import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// Dedicated scanner tab: live document scanning, barcode capture and gallery import.
struct ScanView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language

    @StateObject private var scanner = ScannerCoordinator()
    @State private var isPresentingCamera = false
    @State private var isPresentingBarcode = false
    @State private var isPresentingGallery = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var lastResult: ScannedReceipt?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                heroCard
                actions
                if let lastResult = lastResult {
                    ScanResultCard(result: lastResult, currency: settings.defaultCurrency)
                }
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.scan, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingCamera) {
            CameraPicker { data in Task { await run(data, source: "Camera") } }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingBarcode) {
            BarcodeScannerSheet { code in
                lastResult = ScannedReceipt(storeName: code, lines: [])
            }
        }
        .photosPicker(isPresented: $isPresentingGallery, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await run(data, source: "Gallery")
                }
                photoSelection = nil
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

    private var heroCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: scanner.isScanning ? "sparkles" : "doc.viewfinder")
                .font(.system(size: 46))
                .foregroundColor(Theme.brand)
                .symbolRenderingMode(.hierarchical)

            Text(L10n.string(.aiReceiptScanner, language: language))
                .font(.title3.weight(.bold))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Take a picture of any paper receipt, and the scanner will parse it and fill the form for you.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if scanner.isScanning {
                ProgressView().padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                SoftActionButton(titleKey: .gallery, systemImage: "photo.on.rectangle") {
                    isPresentingGallery = true
                }
                SoftActionButton(titleKey: .camera, systemImage: "camera") {
                    isPresentingCamera = true
                }
            }
            if DataScannerViewController.isSupported {
                SoftActionButton(titleKey: .scanBarcode, systemImage: "barcode.viewfinder") {
                    isPresentingBarcode = true
                }
            }
            PrimaryButton(titleKey: .newReceipt, systemImage: "plus") {
                navigation.selected = .newReceipt
            }
        }
    }

    private func run(_ data: Data, source: String) async {
        do {
            let result = try await scanner.scan(
                imageData: data,
                source: source,
                currencySymbol: settings.defaultCurrency.symbol
            )
            lastResult = result
            settings.recordScan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Summary of the most recent scan, so the user can sanity-check the parse.
private struct ScanResultCard: View {
    let result: ScannedReceipt
    let currency: Currency

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(result.storeName ?? L10n.string(.receiptDetails, language: language))
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            if let address = result.address {
                Text(address)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            if result.lines.isEmpty {
                Text(L10n.string(.notEnoughData, language: language))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in
                    HStack {
                        Text("\(line.quantity) × \(line.name)")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(CurrencyFormatter.string(line.unitPrice * Decimal(line.quantity), currency: currency))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if let total = result.total {
                Divider()
                HStack {
                    Text(L10n.string(.grandTotal, language: language))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(CurrencyFormatter.string(total, currency: currency))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .foregroundColor(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
