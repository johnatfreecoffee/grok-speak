import AppKit

/// Custom Grok Speak icon: official Grok comet + iOS-style voice-wave bars.
let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: make-icon.swift <GrokComet.svg> <icon-1024.png>\n", stderr)
    exit(1)
}

let cometURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
guard let comet = NSImage(contentsOf: cometURL) else {
    fputs("failed to load \(cometURL.path)\n", stderr)
    exit(1)
}

let px = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: px,
    pixelsHigh: px,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(2) }
rep.size = NSSize(width: px, height: px)

NSGraphicsContext.saveGraphicsState()
guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(3) }
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high
ctx.shouldAntialias = true
ctx.cgContext.setAllowsAntialiasing(true)

let canvas = NSRect(x: 0, y: 0, width: px, height: px)
NSColor.clear.setFill()
canvas.fill()

let radius = CGFloat(px) * 0.223
let squircle = NSBezierPath(roundedRect: canvas, xRadius: radius, yRadius: radius)
NSColor(srgbRed: 11 / 255, green: 18 / 255, blue: 32 / 255, alpha: 1).setFill()
squircle.fill()
squircle.addClip()

let inset = CGFloat(px) * 0.04
comet.draw(
    in: NSRect(x: inset, y: inset, width: CGFloat(px) - inset * 2, height: CGFloat(px) - inset * 2),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)

// Voice wave — same 5-bar capsule shape as the screenshot, sitting in the comet.
let heights: [CGFloat] = [0.38, 0.72, 1.0, 0.58, 0.46]
let maxH = CGFloat(px) * 0.36
let barW = CGFloat(px) * 0.052
let gap = CGFloat(px) * 0.03
let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = (CGFloat(px) - total) / 2
let midY = CGFloat(px) / 2
NSColor.white.setFill()
for hFrac in heights {
    let h = maxH * hFrac
    let y = midY - h / 2
    NSBezierPath(
        roundedRect: NSRect(x: x, y: y, width: barW, height: h),
        xRadius: barW / 2,
        yRadius: barW / 2
    ).fill()
    x += barW + gap
}

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(4) }
try png.write(to: outURL)
fputs("wrote \(outURL.path)\n", stderr)
