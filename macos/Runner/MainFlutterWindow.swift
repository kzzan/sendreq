import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let fixedSize = NSSize(width: 1440, height: 900)
    let windowFrame = NSRect(origin: self.frame.origin, size: fixedSize)
    self.contentViewController = flutterViewController
    self.title = "sendreq"
    // 固定窗口尺寸由原生启动层负责，Flutter 只渲染产品界面。
    self.minSize = fixedSize
    self.maxSize = fixedSize
    self.styleMask.remove(.resizable)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
