import UIKit
import WebKit
import SafariServices
import CoreLocation
import Network

/// المتحكم الرئيسي: عرض الموقع كاملاً داخل WKWebView مع كل المزايا الاحترافية.
/// محاكاة MainActivity.java في تطبيق أندرويد المعتمد v1.1.0 بمزايا iOS الأصلية:
/// - شريط تقدم علوي · سحب للتحديث · إيماءة الرجوع بالسحب من الحافة
/// - شاشة «لا يوجد اتصال» مع إعادة محاولة يدوية وتلقائية
/// - فتح الروابط الخارجية (tel/mailto/whatsapp/nطاقات خارجية) خارج التطبيق
/// - رفع الملفات والكاميرا/الميكروفون والموقع الجغرافي بأذونات النظام
/// - حفظ كامل للجلسة (Cookies/localStorage) بين الإطلاقات
final class WebViewController: UIViewController {

    // MARK: — العناصر

    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let refreshControl = UIRefreshControl()
    private var offlineView: OfflineView!
    private var progressObserver: NSKeyValueObservation?
    private let pathMonitor = NWPathMonitor()
    private let locationManager = CLLocationManager()
    private var lastLoadFailed = false

    // MARK: — الدورة الحياتية

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupWebView()
        setupProgress()
        setupOfflineView()
        setupNetworkMonitor()
        loadHome()
    }

    deinit {
        progressObserver?.invalidate()
        pathMonitor.cancel()
    }

    // MARK: — البناء

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        // جلسة دائمة: يبقى الولوج (توكن/كوكيز) بين الإطلاقات
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        // تشغيل الوسائط داخل الصفحة بسلاسة (كالموقع)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // تمييز طلبات التطبيق في تحليلات الموقع دون تغيير أي سلوك
        configuration.applicationNameForUserAgent = "AitTegrineCenteriOS/\(Config.appVersion)"

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.backgroundColor = Theme.background
        view.addSubview(webView)

        // سحب للتحديث — كسلوك التطبيقات الأصلية
        refreshControl.tintColor = Theme.primary
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupProgress() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = Theme.primary
        progressView.trackTintColor = Theme.primaryLight.withAlphaComponent(0.5)
        progressView.isHidden = true
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])

        progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            guard let self = self else { return }
            let p = Float(web.estimatedProgress)
            self.progressView.progress = p
            self.progressView.isHidden = p >= 1.0
        }
    }

    private func setupOfflineView() {
        offlineView = OfflineView()
        offlineView.translatesAutoresizingMaskIntoConstraints = false
        offlineView.isHidden = true
        offlineView.onRetry = { [weak self] in self?.loadHome() }
        view.addSubview(offlineView)
        NSLayoutConstraint.activate([
            offlineView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if path.status == .satisfied && self.lastLoadFailed {
                // عودة الاتصال تلقائياً — كسلوك تطبيق أندرويد
                DispatchQueue.main.async { self.loadHome() }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.aittegrine.center.network"))
    }

    // MARK: — التحميل

    func loadHome() {
        lastLoadFailed = false
        hideOffline()
        var request = URLRequest(url: Config.baseURL)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }

    @objc private func pullToRefresh() {
        webView.reload()
    }

    /// استخراج توكن الجلسة من localStorage بالموقع بعد كل تحميل كامل،
    /// ليستعمله جالب الإشعارات الأصلية (نفس آلية التوكن في أندرويد).
    private func syncToken() {
        let js = "window.localStorage.getItem('\(Config.webTokenKey)') || '';"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let token = result as? String, !token.isEmpty else { return }
            UserDefaults.standard.set(token, forKey: Config.storedTokenKey)
        }
    }

    // MARK: — شاشة عدم الاتصال

    private func showOffline(message: String) {
        lastLoadFailed = true
        offlineView.setMessage(message)
        offlineView.isHidden = false
        refreshControl.endRefreshing()
    }

    private func hideOffline() {
        offlineView.isHidden = true
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain &&
            nsError.code == NSURLErrorNotConnectedToInternet {
            return L10n.Offline.message
        }
        return L10n.loadError(code: nsError.code)
    }
}

// MARK: — WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    /// قرار فتح الروابط: مخططات النظام تُفتح بتطبيقها، النطاقات الخارجية بسفاري،
    /// وموقع المركز فقط يبقى داخل التطبيق.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // مخططات خارجية: هاتف، بريد، واتساب، خرائط…
        if let scheme = url.scheme?.lowercased(),
           ["tel", "telprompt", "sms", "mailto", "whatsapp", "geo", "maps",
            "itms-apps", "itms-appss", "facetime", "facetime-audio"].contains(scheme) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        // نطاق خارجي في الإطار الرئيسي → سفاري (بوابات الدفع وأي خدمات أخرى)
        if navigationAction.targetFrame?.isMainFrame == true,
           url.scheme == "https" || url.scheme == "http",
           !Config.isInternalHost(url.host) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hideOffline()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        lastLoadFailed = false
        hideOffline()
        refreshControl.endRefreshing()
        syncToken()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        showOffline(message: friendlyMessage(for: error))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // فشل تحميل مورد فرعي — الصفحة معروضة، لا حاجة لتغطيتها
        refreshControl.endRefreshing()
    }
}

// MARK: — WKUIDelegate (حوارات JS، رفع الملفات، الكاميرا، الموقع)

extension WebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Dialog.ok, style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Dialog.ok, style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: L10n.Dialog.cancel, style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: L10n.Dialog.ok, style: .default) { [alert] _ in
            completionHandler(alert.textFields?.first?.text)
        })
        alert.addAction(UIAlertAction(title: L10n.Dialog.cancel, style: .cancel) { _ in completionHandler(nil) })
        present(alert, animated: true)
    }

    /// إذن الكاميرا/الميكروفون لصفحات الموقع (استحضار الفيديو وغيره) — النظام يعرض إذنه أولاً
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 completionHandler: @escaping (WKPermissionDecision) -> Void) {
        completionHandler(.grant)
    }

    /// إذن الموقع الجغرافي لصفحات الموقع — مع طلب إذن النظام «أثناء الاستعمال»
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        completionHandler(true)
    }
}

// MARK: — CLLocationManagerDelegate

extension WebViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // الإذن يُعالج بواسطة النظام و WKWebView تلقائياً بعد المنح
    }
}
