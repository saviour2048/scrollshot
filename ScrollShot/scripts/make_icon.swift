#!/usr/bin/env swift
//
// Generates ScrollShot's app icon (all macOS sizes) into
// Resources/Assets.xcassets/AppIcon.appiconset.
//
// Run once on a Mac, from the ScrollShot project dir:
//     cd ScrollShot && swift scripts/make_icon.swift
//
// Then `xcodegen generate` (or just rebuild) and the icon is used.

import AppKit

let entries: [(base: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

/// Draws the icon into the current graphics context at `s`×`s` pixels.
func draw(_ s: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Rounded "squircle" background with a blue gradient.
    let inset = s * 0.06
    let bgRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: bgRect.width * 0.225, yRadius: bgRect.width * 0.225)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.16, green: 0.55, blue: 1.00, alpha: 1),   // top  #2A8CFF
        NSColor(srgbRed: 0.00, green: 0.36, blue: 0.91, alpha: 1)    // bot  #005CE8
    ])!
    bgPath.addClip()
    gradient.draw(in: bgRect, angle: -90)
    NSGraphicsContext.current!.cgContext.resetClip()

    // White "page" (the screenshot) — a tall rounded card.
    let pageW = s * 0.42
    let pageH = s * 0.50
    let pageX = (s - pageW) / 2
    let pageY = s * 0.30
    let page = CGRect(x: pageX, y: pageY, width: pageW, height: pageH)
    let pagePath = NSBezierPath(roundedRect: page, xRadius: s * 0.05, yRadius: s * 0.05)
    NSColor.white.setFill()
    pagePath.fill()

    // Content lines on the page.
    NSColor(white: 0.0, alpha: 0.18).setFill()
    let lineH = s * 0.028
    let lineX = pageX + pageW * 0.16
    let lineW = pageW * 0.68
    for i in 0..<4 {
        let y = page.maxY - pageH * 0.20 - CGFloat(i) * (pageH * 0.16)
        let w = i == 3 ? lineW * 0.6 : lineW
        NSBezierPath(roundedRect: CGRect(x: lineX, y: y, width: w, height: lineH),
                     xRadius: lineH / 2, yRadius: lineH / 2).fill()
    }

    // Downward chevron (scroll / long capture) at the bottom.
    let chevW = s * 0.20
    let chevTop = s * 0.255
    let chevBottom = s * 0.155
    let cx = s / 2
    let chevron = NSBezierPath()
    chevron.move(to: CGPoint(x: cx - chevW / 2, y: chevTop))
    chevron.line(to: CGPoint(x: cx, y: chevBottom))
    chevron.line(to: CGPoint(x: cx + chevW / 2, y: chevTop))
    chevron.lineWidth = s * 0.045
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    NSColor.white.setStroke()
    chevron.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let outDir = "Resources/Assets.xcassets/AppIcon.appiconset"
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for (base, scale) in entries {
    let px = base * scale
    let name = scale == 1 ? "icon_\(base).png" : "icon_\(base)@\(scale)x.png"
    try! render(pixels: px).write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    images.append([
        "idiom": "mac",
        "size": "\(base)x\(base)",
        "scale": "\(scale)x",
        "filename": name
    ])
}

let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(outDir)/Contents.json"))

print("✓ App icon written to \(outDir)")
