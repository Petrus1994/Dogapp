import SwiftUI
import StoreKit

// MARK: - PaywallView
// Full-screen modal shown whenever a premium-only action is attempted.
// Handles purchase, restore, and graceful degradation when no products are loaded.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sub = SubscriptionService.shared

    let trigger: String?
    let dogId: String?

    init(trigger: String? = nil, dogId: String? = nil) {
        self.trigger = trigger
        self.dogId   = dogId
    }

    private var benefits: [(icon: String, text: String)] { [
        ("🤖", "Full AI Trainer — personalised coaching for your dog"),
        ("💬", "Unlimited AI chat — global and activity-specific"),
        ("🎙️", "Voice logging + AI interpretation of behaviour"),
        ("📊", "Deep behaviour analysis and adaptive weekly reviews"),
        ("📋", "Daily plans that evolve based on real progress"),
        ("🐾", "Persistent dog memory — AI grows with your dog"),
        ("😊", "Avatar emotional reactions linked to real progress"),
    ] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {

                    // Hero
                    VStack(spacing: AppTheme.Spacing.s) {
                        Text("⭐️")
                            .font(.system(size: 56))
                            .padding(.top, AppTheme.Spacing.m)
                        Text("Unlock Premium")
                            .font(AppTheme.Font.headline(26))
                        Text("Get the full AI trainer experience,\npersonalised to your dog.")
                            .font(AppTheme.Font.body(16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Benefits card
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        ForEach(benefits, id: \.icon) { benefit in
                            HStack(alignment: .top, spacing: AppTheme.Spacing.m) {
                                Text(benefit.icon)
                                    .font(.system(size: 20))
                                    .frame(width: 30)
                                Text(benefit.text)
                                    .font(AppTheme.Font.body(15))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.m)
                    .cardStyle()
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Purchase section
                    VStack(spacing: AppTheme.Spacing.m) {
                        if sub.products.isEmpty {
                            // No products yet — App Store Connect not configured
                            VStack(spacing: AppTheme.Spacing.s) {
                                PrimaryButton(title: "Unlock Premium", action: {}, isDisabled: true)
                                Text("Pricing not yet available. Configure in App Store Connect.")
                                    .font(AppTheme.Font.caption(12))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            ForEach(sub.products.sorted { a, b in
                                // Monthly before annual in display
                                (a.subscription?.subscriptionPeriod.unit == .month) &&
                                (b.subscription?.subscriptionPeriod.unit != .month)
                            }, id: \.id) { product in
                                PaywallProductButton(
                                    product: product,
                                    isLoading: sub.isPurchasing
                                ) {
                                    Task { await sub.purchase(product) }
                                }
                            }
                        }

                        if let err = sub.purchaseError {
                            Text(err)
                                .font(AppTheme.Font.caption(13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button("Restore Purchases") {
                            Task { await sub.restorePurchases() }
                        }
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Legal note
                    Text("Subscription renews automatically. Cancel anytime in iOS Settings.")
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.l)

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe later") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: sub.status) { _, new in
            if new == .premium {
                if let dogId { sub.setDogPremium(dogId, premium: true) }
                dismiss()
            }
        }
    }
}

// MARK: - Product Button

private struct PaywallProductButton: View {
    let product: Product
    let isLoading: Bool
    let action: () -> Void

    private var periodLabel: String {
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .month: return sub.subscriptionPeriod.value == 1 ? "month" : "\(sub.subscriptionPeriod.value) months"
        case .year:  return "year"
        default:     return ""
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .fill(AnyShapeStyle(AppTheme.orangeGradient))
                    .frame(height: 58)
                    .shadow(color: Color(hex: "#FF9500").opacity(0.35), radius: 8, x: 0, y: 4)

                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text("Unlock Premium")
                            .font(AppTheme.Font.title(16))
                            .foregroundColor(.white)
                        Text("\(product.displayPrice) / \(periodLabel)")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
            }
        }
        .disabled(isLoading)
        .buttonStyle(PressScaleButtonStyle())
    }
}

#Preview {
    PaywallView(trigger: "ai_chat")
}
