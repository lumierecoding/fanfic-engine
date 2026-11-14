import AppKit
import MetalKit
import SwiftUI
import os

/// The window's background (ui-spec change 16): the "aura" of the owner's Fanfiction website (`startseite/aura.js`),
/// as its content pages show it (`data-aura="matt"`): a slow, soft colour field behind a layer of matte glass, with
/// film grain. Ported from the site's WebGL2 shaders to Metal; colours are the site's tokens.
///
/// - **Veil** (the app's default, the owner's choice of 13 November): a soft arc of ink above the ground, in the
///   appearance's own two colours.
/// - **Ridge** (the site's default): an amber ridge line under an ultramarine sky. A night picture, so its colours stay
///   dark in light appearance; the matte glass is tinted toward the light ground then.
///
/// Developer option `-aura ridge|veil|off` (`off`: the system's window background, as before change 16).
enum AuraVariant: String {
    case ridge, veil, off

    static var current: AuraVariant {
        AuraVariant(rawValue: UserDefaults.standard.string(forKey: "aura") ?? "") ?? .veil
    }
}

extension View {
    /// Lists leave their own background out while the aura is on, so it shows between their rows; with `-aura off`
    /// they keep it, as before change 16.
    func auraListBackground() -> some View {
        scrollContentBackground(AuraVariant.current == .off ? .automatic : .hidden)
    }

    /// The aura as the window's background, behind the sidebar, the columns and the toolbar.
    @ViewBuilder
    func auraWindowBackground() -> some View {
        let variant = AuraVariant.current
        if variant == .off {
            self
        } else {
            containerBackground(for: .window) { AuraBackdrop(variant: variant) }
        }
    }
}

/// The aura over the system's window colour, which stays visible if Metal can't draw (as on the site without WebGL2).
private struct AuraBackdrop: View {
    let variant: AuraVariant
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            AuraLayer(variant: variant, dark: colorScheme == .dark, still: Motion.reduced(reduceMotion))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct AuraLayer: NSViewRepresentable {
    let variant: AuraVariant
    let dark: Bool
    let still: Bool

    func makeNSView(context: Context) -> AuraView { AuraView() }

    func updateNSView(_ view: AuraView, context: Context) {
        view.configure(variant: variant, dark: dark, still: still)
    }
}

/// Draws the aura with Metal in two passes, as the site does: the field (blurred for the matte glass) at a quarter of
/// the resolution, then the glass's scatter, tint, haze and frost texture and the grain at full resolution (at most
/// 1.5 pixels per point, as on the site).
///
/// Motion (the site's "Drift"): the field flows slowly and the grain flickers, drawn 15 times a second. It stands still
/// with Reduce Motion (the site's "Hold") and in Low Power Mode, and pauses while the window is hidden or another app
/// is in front, so the background costs nothing then; it goes on from where it stopped.
final class AuraView: MTKView {
    private static let log = Logger(subsystem: "io.github.lumierecoding.fanficengine", category: "aura")
    private static let framesPerSecond = 15
    private static let grainFramesPerSecond = 12.0
    private static let maxPixelsPerPoint: CGFloat = 1.5

    private var variant = AuraVariant.veil
    private var dark = false
    private var still = false
    private var configured = false

    private var queue: MTLCommandQueue?
    private var pipelines: AuraPipelines?
    private var fieldTexture: MTLTexture?

    /// The field's phase in seconds: it only advances while the aura moves, so it never jumps.
    private var phase: Double = 0
    private var runningSince: CFTimeInterval?
    private var observers: [NSObjectProtocol] = []

    init() {
        let device = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm  // not _srgb: the colours mix in gamma space, as in WebGL on the site
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        framebufferOnly = true
        autoResizeDrawable = false
        queue = device?.makeCommandQueue()
        if let device { pipelines = AuraPipelines.shared(for: device) }
        layer?.isOpaque = pipelines != nil  // without shaders nothing is drawn, and the window's colour shows
        isPaused = true
        enableSetNeedsDisplay = true
    }

    required init(coder: NSCoder) { fatalError("not used") }

    /// The background takes no clicks; they go to the window as before.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(variant: AuraVariant, dark: Bool, still: Bool) {
        guard !configured || variant != self.variant || dark != self.dark || still != self.still else { return }
        configured = true
        self.variant = variant
        self.dark = dark
        self.still = still
        updateRunning()
        needsDisplay = true
    }

    // MARK: Size

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    private var pixelsPerPoint: CGFloat {
        min(window?.backingScaleFactor ?? 2, Self.maxPixelsPerPoint)
    }

    private func updateDrawableSize() {
        let scale = pixelsPerPoint
        let size = CGSize(width: max(2, (bounds.width * scale).rounded()), height: max(2, (bounds.height * scale).rounded()))
        guard size != drawableSize else { return }
        drawableSize = size
        // While it moves, the next frame would only come with the next tick, and a window being resized would show the
        // old frame stretched until then; so draw now.
        if isPaused { needsDisplay = true } else { draw() }
    }

    // MARK: When it moves

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { updateRunning(); return }
        let center = NotificationCenter.default
        let names: [(Notification.Name, AnyObject?)] = [
            (NSWindow.didChangeOcclusionStateNotification, window),
            (NSApplication.didBecomeActiveNotification, NSApp),
            (NSApplication.didResignActiveNotification, NSApp),
            (.NSProcessInfoPowerStateDidChange, nil),
        ]
        observers = names.map { name, object in
            center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRunning() }
            }
        }
        updateDrawableSize()
        updateRunning()
    }

    /// Developer option `-auraKeepMoving YES`: moves while another app is in front too, to measure the cost and capture
    /// the motion of a test copy started in the background.
    private static let keepMoving = UserDefaults.standard.bool(forKey: "auraKeepMoving")

    private var shouldMove: Bool {
        guard let window, pipelines != nil, !still else { return false }
        return window.occlusionState.contains(.visible)
            && (NSApp.isActive || Self.keepMoving)
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private func updateRunning() {
        let move = shouldMove
        if move, runningSince == nil {
            runningSince = CACurrentMediaTime()
            preferredFramesPerSecond = Self.framesPerSecond
            enableSetNeedsDisplay = false
            isPaused = false
        } else if !move, let since = runningSince {
            phase += CACurrentMediaTime() - since
            runningSince = nil
            isPaused = true
            enableSetNeedsDisplay = true
            needsDisplay = true
        }
    }

    private var currentPhase: Double {
        phase + (runningSince.map { CACurrentMediaTime() - $0 } ?? 0)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let queue, let pipelines, let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let buffer = queue.makeCommandBuffer() else { return }
        let width = Int(drawableSize.width), height = Int(drawableSize.height)
        guard let field = fieldTexture(width: (width + 3) / 4, height: (height + 3) / 4) else { return }

        let moving = runningSince != nil
        let t = currentPhase
        let palette = AuraPalette(variant: variant, dark: dark)
        let scale = Float(pixelsPerPoint)

        // Pass 1: the field, blurred by the matte glass, at a quarter of the resolution.
        var fieldUniforms = AuraFieldUniforms(
            res: SIMD2(Float(field.width), Float(field.height)),
            variant: variant == .veil ? 1 : 0,
            frost: 1,
            wander: SIMD4(Self.wander(t, 1), Self.wander(t, 2), Self.wander(t, 3), Self.wander(t, 4)),
            blurStep: SIMD2(12 * scale / Float(width), 12 * scale / Float(height)),
            ground: palette.ground, ink: palette.ink, amber: palette.amber, amberHi: palette.amberHi,
            ember: palette.ember, ultra: palette.ultra, abyss: palette.abyss, void: palette.void)
        let fieldPass = MTLRenderPassDescriptor()
        fieldPass.colorAttachments[0].texture = field
        fieldPass.colorAttachments[0].loadAction = .dontCare
        fieldPass.colorAttachments[0].storeAction = .store
        if let encoder = buffer.makeRenderCommandEncoder(descriptor: fieldPass) {
            encoder.setRenderPipelineState(pipelines.field)
            encoder.setFragmentBytes(&fieldUniforms, length: MemoryLayout<AuraFieldUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        }

        // Pass 2: the glass's scatter, tint, milky haze and frost texture, then the grain.
        var compositeUniforms = AuraCompositeUniforms(
            res: SIMD2(Float(width), Float(height)),
            seed: moving ? Float((t * Self.grainFramesPerSecond).rounded(.down).truncatingRemainder(dividingBy: 4096)) : 7,
            grain: dark ? 0.05 : 0.06,
            tintAmount: dark ? 0.42 : (variant == .ridge ? 0.72 : 0.5),
            pixelsPerPoint: scale,
            frost: 1,
            tint: palette.tint, milk: palette.milk)
        pass.colorAttachments[0].loadAction = .dontCare
        if let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setRenderPipelineState(pipelines.composite)
            encoder.setFragmentBytes(&compositeUniforms, length: MemoryLayout<AuraCompositeUniforms>.stride, index: 0)
            encoder.setFragmentTexture(field, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        }
        buffer.present(drawable)
        buffer.commit()
    }

    private func fieldTexture(width: Int, height: Int) -> MTLTexture? {
        if let fieldTexture, fieldTexture.width == width, fieldTexture.height == height { return fieldTexture }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        fieldTexture = device?.makeTexture(descriptor: descriptor)
        return fieldTexture
    }

    /// The site's `w1`: a smooth wander, 0 at t = 0, roughly within [-1, 1]. The same for every pixel, so worked out
    /// once per frame here.
    private static func wander(_ t: Double, _ s: Double) -> Float {
        let a = 0.6 * sin(t * 0.23 + s * 1.7) + 0.4 * sin(t * 0.137 + s * 4.3)
        let b = 0.6 * sin(s * 1.7) + 0.4 * sin(s * 4.3)
        return Float(0.5 * (a - b))
    }

    fileprivate static func logFailure(_ message: String) { log.error("\(message, privacy: .public)") }
}

/// The site's colour tokens (`startseite/index.html`, `:root`). Ridge uses the night set, which is the same in both
/// appearances; Veil and the glass use the appearance's own ground and ink.
private struct AuraPalette {
    var ground, ink, amber, amberHi, ember, ultra, abyss, void: SIMD4<Float>
    /// The glass is tinted toward the ground, so text on it stays readable; the haze goes toward the ink.
    var tint, milk: SIMD4<Float>

    init(variant: AuraVariant, dark: Bool) {
        let theme = dark
            ? (ground: 0x0b0b0c, ink: 0xeeeeea, amber: 0xf7932a, amberHi: 0xfbb555, ember: 0xc75a1e,
               ultra: 0x2f5bff, abyss: 0x020722, void: 0x000000)
            : (ground: 0xe8e8e3, ink: 0x121213, amber: 0xb85c06, amberHi: 0xa35003, ember: 0xd9661f,
               ultra: 0x1d45d8, abyss: 0x020722, void: 0xd6d6d1)
        let night = (ground: 0x0b0b0c, ink: 0xeeeeea, amber: 0xf7932a, amberHi: 0xfbb555, ember: 0xc75a1e,
                     ultra: 0x2f5bff, abyss: 0x020722, void: 0x000000)
        let field = variant == .ridge ? night : theme
        ground = Self.rgb(field.ground); ink = Self.rgb(field.ink)
        amber = Self.rgb(field.amber); amberHi = Self.rgb(field.amberHi); ember = Self.rgb(field.ember)
        ultra = Self.rgb(field.ultra); abyss = Self.rgb(field.abyss); void = Self.rgb(field.void)
        tint = Self.rgb(theme.ground)
        milk = Self.rgb(theme.ink)
    }

    private static func rgb(_ hex: Int) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 255) / 255, Float((hex >> 8) & 255) / 255, Float(hex & 255) / 255, 1)
    }
}

// The uniforms, laid out as the structs in the shader (16-byte colours, so no hidden padding).
private struct AuraFieldUniforms {
    var res: SIMD2<Float>
    var variant: Int32
    var frost: Int32
    var wander: SIMD4<Float>
    var blurStep: SIMD2<Float>
    var pad = SIMD2<Float>(0, 0)
    var ground, ink, amber, amberHi, ember, ultra, abyss, void: SIMD4<Float>
}

private struct AuraCompositeUniforms {
    var res: SIMD2<Float>
    var seed: Float
    var grain: Float
    var tintAmount: Float
    var pixelsPerPoint: Float
    var frost: Float
    var pad: Float = 0
    var tint, milk: SIMD4<Float>
}

/// The two render pipelines, compiled once from the shader source below (the app has no Metal build step).
@MainActor
private final class AuraPipelines {
    let field: MTLRenderPipelineState
    let composite: MTLRenderPipelineState

    private static var cache: [ObjectIdentifier: AuraPipelines] = [:]
    private static var failed = false

    private init(field: MTLRenderPipelineState, composite: MTLRenderPipelineState) {
        self.field = field
        self.composite = composite
    }

    static func shared(for device: MTLDevice) -> AuraPipelines? {
        let key = ObjectIdentifier(device)
        if let cached = cache[key] { return cached }
        guard !failed else { return nil }
        do {
            let library = try device.makeLibrary(source: auraShaderSource, options: nil)
            func pipeline(_ fragment: String, _ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "aura_vertex")
                descriptor.fragmentFunction = library.makeFunction(name: fragment)
                descriptor.colorAttachments[0].pixelFormat = format
                return try device.makeRenderPipelineState(descriptor: descriptor)
            }
            let made = AuraPipelines(field: try pipeline("aura_field", .rgba16Float),
                                     composite: try pipeline("aura_composite", .bgra8Unorm))
            cache[key] = made
            return made
        } catch {
            failed = true
            AuraView.logFailure("The aura's shaders did not compile: \(error)")
            return nil
        }
    }
}

/// The site's field and composite shaders (`aura.js`), in Metal. Metal's pixel origin is the top-left corner, so `uv.y`
/// is 0 at the top as on the site without its `1.0 - y`.
private let auraShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct FieldU {
    float2 res; int variant; int frost;
    float4 w;          // w1(T, 1…4)
    float2 blurStep; float2 pad;
    float4 ground, ink, amber, amberHi, ember, ultra, abyss, voidC;
};
struct CompU {
    float2 res; float seed; float grain;
    float tintAmt; float dpr; float frost; float pad;
    float4 tint, milk;
};
struct VOut { float4 pos [[position]]; };

vertex VOut aura_vertex(uint vid [[vertex_id]]) {
    float2 p = float2(float((vid << 1) & 2), float(vid & 2));
    VOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

static float3 amberRamp(float g, constant FieldU &u) {
    float3 c = mix(u.ember.rgb, u.amber.rgb, smoothstep(0.30, 0.70, g));
    return mix(c, u.amberHi.rgb, smoothstep(0.72, 0.98, g));
}

static float3 veil(float2 uv, float A, constant FieldU &u) {
    float2 q = float2(uv.x * A, uv.y);
    float2 c = float2(0.5 * A + 0.12 * A * u.w.x, 1.58 + 0.07 * u.w.y);
    float R = 1.30 + 0.05 * u.w.z;
    float dist = length(q - c) - R;
    float th = 0.085 + 0.025 * u.w.w;
    float band = exp(-(dist * dist) / (th * th));
    return mix(u.ground.rgb, u.ink.rgb, band * 0.84);
}

static float3 ridge(float2 uv, constant FieldU &u) {
    float yr = 0.62 - 0.16 * sin(uv.x * 3.4 + 0.5 + 0.6 * u.w.x) + 0.05 * u.w.y;
    float3 sky = mix(u.ultra.rgb, u.abyss.rgb, smoothstep(0.0, 0.9, uv.y));
    float dy = max(yr - uv.y, 0.0);
    float glow = exp(-dy * dy / 0.010);
    float3 col = mix(sky, amberRamp(glow * 0.85, u), smoothstep(0.05, 0.9, glow) * 0.95);
    float below = smoothstep(-0.02, 0.05, uv.y - yr);
    return mix(col, mix(u.voidC.rgb, u.abyss.rgb, 0.6), below);
}

static float3 field(float2 uv, constant FieldU &u) {
    uv = clamp(uv, 0.0, 1.0);   // the site's texture clamps at its edges
    return u.variant == 0 ? ridge(uv, u) : veil(uv, u.res.x / u.res.y, u);
}

// Pass 1, a quarter of the resolution: the field, and for the matte glass its 5 × 5 soft blur
// (12 px apart at full resolution, as on the site).
fragment float4 aura_field(VOut in [[stage_in]], constant FieldU &u [[buffer(0)]]) {
    float2 uv = in.pos.xy / u.res;
    if (u.frost == 0) return float4(field(uv, u), 1.0);
    float3 acc = 0.0;
    float wsum = 0.0;
    for (int i = -2; i <= 2; i++) {
        for (int j = -2; j <= 2; j++) {
            float w = exp(-float(i * i + j * j) / 4.5);
            acc += field(uv + float2(float(i), float(j)) * u.blurStep, u) * w;
            wsum += w;
        }
    }
    return float4(acc / wsum, 1.0);
}

static float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Pass 2, full resolution: each pixel looks through the glass a little off to the side, in a fixed random
// direction; the glass is tinted toward the ground, with a faint milky haze and a fixed frost texture; then grain.
fragment float4 aura_composite(VOut in [[stage_in]], constant CompU &u [[buffer(0)]],
                               texture2d<float> fieldTex [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 px = floor(in.pos.xy);
    float2 uv = in.pos.xy / u.res;
    float3 col;
    if (u.frost > 0.5) {
        float2 scatter = (float2(hash(px), hash(px + 19.7)) - 0.5) * 18.0 * u.dpr / u.res;
        col = fieldTex.sample(s, uv + scatter).rgb;
        col = mix(col, u.tint.rgb, u.tintAmt);
        col = mix(col, u.milk.rgb, 0.06);
        col += (hash(px * 0.5 + 3.1) - 0.5) * 0.03;
    } else {
        col = fieldTex.sample(s, uv).rgb;
    }
    float n = hash(px + float2(u.seed * 17.0, u.seed * 31.0)) - 0.5;
    float lum = dot(col, float3(0.299, 0.587, 0.114));
    col += n * u.grain * (0.55 + 1.8 * lum * (1.0 - lum));
    return float4(col, 1.0);
}
"""
