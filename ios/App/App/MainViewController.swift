import UIKit
import WebKit
import Capacitor
import AVFoundation
import Network
import CallKit

public class MainViewController: CAPBridgeViewController, WKUIDelegate, WKNavigationDelegate, CallKitManagerDelegate {
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "CallVexaNetworkMonitor")
    private var isNetworkAvailable = true
    private var isShowingOfflineFallback = false
    private let targetCloudURL = URL(string: "https://callvexa.us")!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 10/255.0, green: 15/255.0, blue: 30/255.0, alpha: 1.0)
        
        setupWKWebView()
        setupAudioSession()
        setupNetworkMonitoring()
        CallKitManager.shared.delegate = self
    }
    
    private func setupWKWebView() {
        guard let webView = self.webView else { return }
        webView.backgroundColor = UIColor(red: 10/255.0, green: 15/255.0, blue: 30/255.0, alpha: 1.0)
        webView.isOpaque = true
        webView.scrollView.backgroundColor = UIColor(red: 10/255.0, green: 15/255.0, blue: 30/255.0, alpha: 1.0)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // Add script message handler for bidirectional communication with CallKit / in-app dialer
        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "callvexaNative")
        
        // Inject script to detect incoming Twilio calls & route them to CallKit and vice versa
        let bridgeScriptSource = """
        (function() {
            window.CallVexaNativeBridge = {
                reportIncoming: function(caller, handle) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.callvexaNative) {
                        window.webkit.messageHandlers.callvexaNative.postMessage({
                            type: 'incomingCall',
                            caller: caller || 'CallVexa Customer',
                            handle: handle || 'CallVexa'
                        });
                    }
                },
                reportEndCall: function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.callvexaNative) {
                        window.webkit.messageHandlers.callvexaNative.postMessage({
                            type: 'endCall'
                        });
                    }
                },
                onCallAnswered: function() {
                    const buttons = Array.from(document.querySelectorAll('button'));
                    const answerBtn = buttons.find(b => b.textContent && b.textContent.trim().toLowerCase() === 'answer');
                    if (answerBtn) {
                        answerBtn.click();
                    }
                },
                onCallDeclined: function() {
                    const buttons = Array.from(document.querySelectorAll('button'));
                    const declineBtn = buttons.find(b => b.textContent && b.textContent.trim().toLowerCase() === 'decline');
                    if (declineBtn) {
                        declineBtn.click();
                    }
                }
            };

            // Observer to automatically detect CallVexa incoming call banner
            const observer = new MutationObserver(function() {
                const buttons = Array.from(document.querySelectorAll('button'));
                const hasAnswer = buttons.some(b => b.textContent && b.textContent.trim().toLowerCase() === 'answer');
                const hasDecline = buttons.some(b => b.textContent && b.textContent.trim().toLowerCase() === 'decline');
                
                if (hasAnswer && hasDecline && !window.__callVexaReportedIncoming) {
                    window.__callVexaReportedIncoming = true;
                    let callerName = 'Incoming Call';
                    const banners = document.querySelectorAll('div');
                    for (let el of banners) {
                        if (el.textContent && el.textContent.includes('Incoming call from')) {
                            callerName = el.textContent.trim();
                            break;
                        }
                    }
                    window.CallVexaNativeBridge.reportIncoming(callerName, 'CallVexa');
                } else if (!hasAnswer && !hasDecline && window.__callVexaReportedIncoming) {
                    window.__callVexaReportedIncoming = false;
                    window.CallVexaNativeBridge.reportEndCall();
                }
            });

            if (document.body) {
                observer.observe(document.body, { childList: true, subtree: true });
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    observer.observe(document.body, { childList: true, subtree: true });
                });
            }
        })();
        """
        let bridgeScript = WKUserScript(source: bridgeScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(bridgeScript)
    }
    
    // MARK: - WKUIDelegate: WebRTC & Camera/Microphone Permissions
    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    // MARK: - Navigation Handling & External Links
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        
        // Handle external links: WhatsApp, phone dialer, SMS, email
        if scheme == "tel" || scheme == "sms" || scheme == "mailto" || scheme == "whatsapp" || host == "wa.me" || host == "api.whatsapp.com" {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    // MARK: - Navigation Failure / Offline Handling
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error: error)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error: error)
    }
    
    private func handleNavigationFailure(error: Error) {
        let nsError = error as NSError
        print("[CallVexa] Navigation failed: \(nsError.domain) code: \(nsError.code)")
        
        if nsError.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
            showOfflineFallback()
        }
    }
    
    private func showOfflineFallback() {
        guard !isShowingOfflineFallback, let webView = self.webView else { return }
        isShowingOfflineFallback = true
        if let offlineURL = Bundle.main.url(forResource: "public/index", withExtension: "html") {
            webView.loadFileURL(offlineURL, allowingReadAccessTo: offlineURL.deletingLastPathComponent())
        }
    }
    
    private func reloadCloudApp() {
        guard isShowingOfflineFallback, let webView = self.webView else { return }
        isShowingOfflineFallback = false
        let request = URLRequest(url: targetCloudURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15.0)
        webView.load(request)
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let online = (path.status == .satisfied)
            self.isNetworkAvailable = online
            DispatchQueue.main.async {
                if online && self.isShowingOfflineFallback {
                    print("[CallVexa] Network connection restored. Reloading https://callvexa.us")
                    self.reloadCloudApp()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Audio Session Configuration for VoIP & Background Calling
    public static func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[CallVexa] AudioSession error: \(error)")
        }
    }
    
    private func setupAudioSession() {
        MainViewController.configureAudioSession()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .ended {
            MainViewController.configureAudioSession()
        }
    }
    
    // MARK: - CallKitManagerDelegate
    public func callDidAnswer(uuid: UUID) {
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("if (window.CallVexaNativeBridge) window.CallVexaNativeBridge.onCallAnswered();", completionHandler: nil)
        }
    }
    
    public func callDidEnd(uuid: UUID) {
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("if (window.CallVexaNativeBridge) window.CallVexaNativeBridge.onCallDeclined();", completionHandler: nil)
        }
    }
    
    public func callDidMute(uuid: UUID, isMuted: Bool) {
        print("[CallKit] Call muted: \(isMuted)")
    }
    
    deinit {
        monitor.cancel()
    }
}

extension MainViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "callvexaNative",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        if type == "incomingCall" {
            let caller = dict["caller"] as? String ?? "CallVexa Customer"
            let handle = dict["handle"] as? String ?? "CallVexa"
            CallKitManager.shared.reportIncomingCall(uuid: UUID(), callerName: caller, handle: handle)
        } else if type == "endCall" {
            if let activeUUID = CallKitManager.shared.activeCallUUID {
                CallKitManager.shared.endCall(uuid: activeUUID)
            }
        }
    }
}
