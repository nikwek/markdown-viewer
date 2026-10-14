// Draws the app icon at 1024px. Usage: swift make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS icon grid: the rounded square sits inset within the canvas.
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
shadow.set()
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(
    starting: NSColor(calibratedRed: 0.27, green: 0.35, blue: 0.95, alpha: 1),
    ending: NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.85, alpha: 1)
)!.draw(in: shape, angle: -60)

// "M" and a down arrow: the Markdown mark.
let ink = NSColor.white
ink.setStroke()
ink.setFill()
let stroke: CGFloat = 70

let m = NSBezierPath()
m.lineWidth = stroke
m.lineJoinStyle = .round
m.lineCapStyle = .round
m.move(to: NSPoint(x: 250, y: 360))
m.line(to: NSPoint(x: 250, y: 660))
m.line(to: NSPoint(x: 385, y: 510))
m.line(to: NSPoint(x: 520, y: 660))
m.line(to: NSPoint(x: 520, y: 360))
m.stroke()

let shaft = NSBezierPath()
shaft.lineWidth = stroke
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 690, y: 660))
shaft.line(to: NSPoint(x: 690, y: 470))
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 590, y: 480))
head.line(to: NSPoint(x: 790, y: 480))
head.line(to: NSPoint(x: 690, y: 350))
head.close()
head.fill()

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
