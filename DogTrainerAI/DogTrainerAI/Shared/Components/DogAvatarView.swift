import SwiftUI

/// Animated SwiftUI dog avatar.
/// Reflects the dog's current state and coat color.
/// Designed to be Lottie-replaceable: swap internals without changing the call site.
struct DogAvatarView: View {
    let avatarState: DogAvatarState
    let coatColor: CoatColor
    var size: CGFloat = 160

    // MARK: - Animation state
    @State private var breathPhase: Double = 0
    @State private var tailAngle: Double = -20
    @State private var eyeBlink: Bool = false
    @State private var bodyBounce: CGFloat = 0
    @State private var headTilt: Double = 0

    // Timers
    @State private var breathTimer: Timer?
    @State private var tailTimer: Timer?
    @State private var blinkTimer: Timer?
    @State private var bounceTimer: Timer?

    var body: some View {
        ZStack {
            dogBody
        }
        .frame(width: size, height: size)
        .onAppear { startAnimations() }
        .onDisappear { stopAnimations() }
        .onChange(of: avatarState) { _ in
            stopAnimations()
            startAnimations()
        }
    }

    // MARK: - Dog Shape

    private var dogBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)

            ZStack {
                // Shadow
                Ellipse()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: s * 0.70, height: s * 0.12)
                    .offset(y: s * 0.38)

                // Tail
                tail(scale: s)
                    .rotationEffect(.degrees(tailAngle), anchor: UnitPoint(x: 0.1, y: 0.5))
                    .offset(x: -s * 0.28, y: s * 0.05)

                // Body
                Ellipse()
                    .fill(coatColor.primary)
                    .frame(width: s * 0.58, height: s * 0.42)
                    .offset(y: bodyBounce + (avatarState == .sleeping ? s * 0.05 : 0))
                    .scaleEffect(x: 1.0, y: 1.0 + breathPhase * 0.02)

                // Chest / belly lighter patch
                Ellipse()
                    .fill(coatColor.secondary.opacity(0.7))
                    .frame(width: s * 0.28, height: s * 0.26)
                    .offset(x: s * 0.12, y: s * 0.06 + bodyBounce)

                // Head
                head(scale: s)
                    .offset(x: s * 0.22, y: -s * 0.16 + bodyBounce * 0.5)
                    .rotationEffect(.degrees(headTilt), anchor: UnitPoint(x: 0.5, y: 0.8))

                // Front legs
                legs(scale: s)
                    .offset(y: bodyBounce)

                // State label bubble (optional — shown for anxious/excited)
                if avatarState == .excited || avatarState == .anxious {
                    stateBubble
                        .offset(x: s * 0.36, y: -s * 0.38)
                }
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Sub-views

    private func head(scale s: CGFloat) -> some View {
        ZStack {
            // Head base
            Circle()
                .fill(coatColor.primary)
                .frame(width: s * 0.38, height: s * 0.38)

            // Muzzle
            Ellipse()
                .fill(coatColor.secondary)
                .frame(width: s * 0.22, height: s * 0.16)
                .offset(x: s * 0.06, y: s * 0.08)

            // Nose
            Circle()
                .fill(coatColor.accent)
                .frame(width: s * 0.07, height: s * 0.07)
                .offset(x: s * 0.10, y: s * 0.05)

            // Eyes
            eyes(scale: s)

            // Ears
            ears(scale: s)
        }
    }

    private func eyes(scale s: CGFloat) -> some View {
        let open = avatarState.eyeOpenFraction
        return ZStack {
            // Left eye
            ZStack {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: s * 0.08, height: s * 0.08 * max(open, 0.05))
                if open > 0.2 {
                    Circle()
                        .fill(Color(red: 0.25, green: 0.15, blue: 0.05))
                        .frame(width: s * 0.045, height: s * 0.045)
                    // Shine dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: s * 0.015, height: s * 0.015)
                        .offset(x: s * 0.012, y: -s * 0.01)
                }
            }
            .offset(x: -s * 0.05, y: -s * 0.04)
            .scaleEffect(y: eyeBlink ? 0.05 : 1.0)

            // Right eye
            ZStack {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: s * 0.08, height: s * 0.08 * max(open, 0.05))
                if open > 0.2 {
                    Circle()
                        .fill(Color(red: 0.25, green: 0.15, blue: 0.05))
                        .frame(width: s * 0.045, height: s * 0.045)
                    Circle()
                        .fill(Color.white)
                        .frame(width: s * 0.015, height: s * 0.015)
                        .offset(x: s * 0.012, y: -s * 0.01)
                }
            }
            .offset(x: s * 0.06, y: -s * 0.04)
            .scaleEffect(y: eyeBlink ? 0.05 : 1.0)
        }
    }

    private func ears(scale s: CGFloat) -> some View {
        let droop = avatarState == .tired || avatarState == .anxious
        return ZStack {
            // Left ear
            Ellipse()
                .fill(coatColor.primary.darker(by: 0.1))
                .frame(width: s * 0.14, height: s * 0.22)
                .rotationEffect(.degrees(droop ? 20 : -10))
                .offset(x: -s * 0.12, y: -s * 0.14)

            // Right ear
            Ellipse()
                .fill(coatColor.primary.darker(by: 0.1))
                .frame(width: s * 0.14, height: s * 0.22)
                .rotationEffect(.degrees(droop ? -20 : 10))
                .offset(x: s * 0.12, y: -s * 0.14)
        }
    }

    private func tail(scale s: CGFloat) -> some View {
        Capsule()
            .fill(coatColor.primary)
            .frame(width: s * 0.10, height: s * 0.32)
            .rotationEffect(.degrees(-30))
    }

    private func legs(scale s: CGFloat) -> some View {
        ZStack {
            // Front left
            Capsule()
                .fill(coatColor.primary)
                .frame(width: s * 0.09, height: s * 0.20)
                .offset(x: s * 0.08, y: s * 0.24)

            // Front right
            Capsule()
                .fill(coatColor.primary)
                .frame(width: s * 0.09, height: s * 0.20)
                .offset(x: s * 0.20, y: s * 0.24)
        }
    }

    private var stateBubble: some View {
        Text(avatarState.emoji)
            .font(.system(size: size * 0.14))
            .padding(4)
            .background(Color.white.opacity(0.9))
            .clipShape(Circle())
            .shadow(radius: 2)
    }

    // MARK: - Animation Engine

    private func startAnimations() {
        let speed = avatarState.animationSpeed

        // Breathing loop
        withAnimation(
            Animation.easeInOut(duration: 2.0 / speed).repeatForever(autoreverses: true)
        ) {
            breathPhase = avatarState == .sleeping ? 0.5 : 1.0
        }

        // Tail wag
        if avatarState.tailWagIntensity > 0 {
            let amplitude = 15.0 * avatarState.tailWagIntensity
            let duration  = 0.35 / speed
            tailTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
                withAnimation(.easeInOut(duration: duration)) {
                    tailAngle = tailAngle > 0 ? -amplitude : amplitude
                }
            }
        } else {
            tailAngle = -5
        }

        // Body bounce (excited)
        if avatarState.doesBounce {
            bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    bodyBounce = bodyBounce < 0 ? 0 : -size * 0.04
                }
            }
        } else {
            bodyBounce = 0
        }

        // Head tilt (curious when happy)
        if avatarState == .happy {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                headTilt = 8
            }
        } else if avatarState == .anxious {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                headTilt = -5
            }
        } else {
            headTilt = 0
        }

        // Blink — random interval
        scheduleBlink()
    }

    private func scheduleBlink() {
        guard avatarState != .sleeping else { return }
        let delay = Double.random(in: 2.5...6.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.08)) { eyeBlink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.08)) { eyeBlink = false }
                scheduleBlink()
            }
        }
    }

    private func stopAnimations() {
        tailTimer?.invalidate();   tailTimer   = nil
        blinkTimer?.invalidate();  blinkTimer  = nil
        bounceTimer?.invalidate(); bounceTimer = nil
        breathTimer?.invalidate(); breathTimer = nil
    }
}

// MARK: - Color extension

private extension Color {
    func darker(by fraction: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: max(b - CGFloat(fraction), 0), alpha: a))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ForEach([DogAvatarState.sleeping, .tired, .calm, .happy, .excited, .anxious], id: \.label) { state in
                VStack(spacing: 4) {
                    DogAvatarView(avatarState: state, coatColor: .golden, size: 140)
                    Text(state.label).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
