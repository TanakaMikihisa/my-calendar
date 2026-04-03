import SwiftUI

/// 保存中・読み込み中の視覚フィードバック
/// シンボルと、rotationEffectを与える対象は変更しないこと
struct SavingReturnArrowOverlay: View {
    let isSaving: Bool
    /// `true`: Form のセルなど親の枠内にスクリムを収める（`ignoresSafeArea` しない）
    var clipsScrimToParentBounds: Bool = false

    var body: some View {
        ZStack {
            if isSaving {
                Group {
                    if clipsScrimToParentBounds {
                        Color.white.opacity(0.2)
                    } else {
                        Color.white.opacity(0.2)
                            .ignoresSafeArea()
                    }
                }
                .contentShape(Rectangle())

                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate // seconds
                    let rotation = elapsed * 120 // degrees (120 deg / sec)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.black.opacity(0.5))
                            .frame(width: 76, height: 76)
                        Image(systemName: "microbe.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(rotation))
                    }
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
