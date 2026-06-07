#!/usr/bin/env swift

// Generates a 1024×1024 PNG of the Mouse Smooth app icon:
// a slate-gray squircle with the `computermouse.fill` SF Symbol in white,
// matching the menu bar icon. This is the master image the .iconset uses.
//
// Usage:
//   swift Scripts/make-icon.swift path/to/output.png
//
// Pair with sips + iconutil to produce AppIcon.icns — see Scripts/build-icon.sh.

import AppKit
import Foundation

// MARK: - Tuning

// macOS Big Sur+ icon template: visible artwork sits inside an ~824 squircle
// centered on a 1024 canvas. Corner radius ≈ 22% of the squircle gives the
// standard "superellipse" look without actually computing one.
let canvasSize: CGFloat = 1024
let squircleSize: CGFloat = 824
let cornerRadius: CGFloat = 185
let symbolPointSize: CGFloat = 540

// Neutral slate. Reads as Pro / utility, matches the monochrome menu bar.
let backgroundColor = NSColor(red: 0.24, green: 0.27, blue: 0.33, alpha: 1.0)
let symbolColor = NSColor.white

// MARK: - Render

let canvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
canvas.lockFocus()

// Squircle background.
let bgRect = NSRect(
    x: (canvasSize - squircleSize) / 2,
    y: (canvasSize - squircleSize) / 2,
    width: squircleSize,
    height: squircleSize
)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
backgroundColor.setFill()
bgPath.fill()

// White mouse symbol on top.
let baseConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
let colorConfig = NSImage.SymbolConfiguration(paletteColors: [symbolColor])
let config = baseConfig.applying(colorConfig)

guard let baseSymbol = NSImage(systemSymbolName: "computermouse.fill",
                               accessibilityDescription: "Mouse"),
      let symbol = baseSymbol.withSymbolConfiguration(config) else {
    fputs("Failed to load SF Symbol 'computermouse.fill'\n", stderr)
    exit(1)
}

let symbolRect = NSRect(
    x: (canvasSize - symbol.size.width) / 2,
    y: (canvasSize - symbol.size.height) / 2,
    width: symbol.size.width,
    height: symbol.size.height
)
symbol.draw(in: symbolRect)

canvas.unlockFocus()

// MARK: - Save PNG

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath) (\(Int(canvas.size.width))×\(Int(canvas.size.height)))")
} catch {
    fputs("Failed to write \(outPath): \(error)\n", stderr)
    exit(1)
}
