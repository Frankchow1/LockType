#!/usr/bin/env swift
// 用 WebKit 把 SVG 渲染成带透明背景的 PNG
// 用法: svg2png.swift <input.svg> <output.png> <size>

import AppKit
import WebKit

guard CommandLine.arguments.count == 4,
      let size = Int(CommandLine.arguments[3]) else {
    FileHandle.standardError.write("Usage: svg2png.swift <input.svg> <output.png> <size>\n".data(using: .utf8)!)
    exit(1)
}

let svgPath = CommandLine.arguments[1]
let pngPath = CommandLine.arguments[2]

guard let svgData = try? String(contentsOfFile: svgPath, encoding: .utf8) else {
    FileHandle.standardError.write("Cannot read SVG\n".data(using: .utf8)!)
    exit(1)
}

let html = """
<!DOCTYPE html>
<html><head><style>
  html, body { margin:0; padding:0; background:transparent; }
  svg { display:block; width:\(size)px; height:\(size)px; }
</style></head><body>\(svgData)</body></html>
"""

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let cfg = WKWebViewConfiguration()
let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: size, height: size), configuration: cfg)
webView.setValue(false, forKey: "drawsBackground")

class Delegate: NSObject, WKNavigationDelegate {
    let pngPath: String
    let size: Int
    init(pngPath: String, size: Int) { self.pngPath = pngPath; self.size = size }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let cfg = WKSnapshotConfiguration()
            cfg.rect = NSRect(x: 0, y: 0, width: self.size, height: self.size)
            webView.takeSnapshot(with: cfg) { image, error in
                guard let img = image,
                      let tiff = img.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write("snapshot failed: \(error?.localizedDescription ?? "")\n".data(using: .utf8)!)
                    exit(1)
                }
                try? png.write(to: URL(fileURLWithPath: self.pngPath))
                exit(0)
            }
        }
    }
}

let delegate = Delegate(pngPath: pngPath, size: size)
webView.navigationDelegate = delegate
webView.loadHTMLString(html, baseURL: nil)

app.run()
