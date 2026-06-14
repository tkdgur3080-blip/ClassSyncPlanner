import Foundation
import Combine
import WebKit

final class EclassSyncManager: ObservableObject {
    enum SyncState: Equatable {
        case welcome
        case loginRequired
        case syncing(String)
        case finished
        case failed(String)
    }

    @Published var state: SyncState = .welcome
    @Published var result = SyncResult()

    private let parser = HTMLParser.shared
    private var didStartSync = false

    private var collectedAssignments: [AssignmentItem] = []
    private var collectedLectures: [LectureProgressItem] = []
    private var collectedNotices: [NoticeItem] = []

    func beginLogin() {
        didStartSync = false
        result = SyncResult()
        collectedAssignments = []
        collectedLectures = []
        collectedNotices = []
        state = .loginRequired
    }

    func startIfPossible(webView: WKWebView) {
        guard !didStartSync else { return }
        let url = webView.url?.absoluteString ?? ""
        guard !url.contains("/login") else { return }

        evaluateHTML(webView) { [weak self] html in
            guard let self = self else { return }
            let courses = self.parser.parseCourses(from: html)
            if courses.isEmpty { return }
            self.didStartSync = true
            self.startSync(courses: courses, webView: webView)
        }
    }

    func resetToStart() {
        didStartSync = false
        collectedAssignments = []
        collectedLectures = []
        collectedNotices = []
        result = SyncResult()
        state = .welcome
    }

    private func startSync(courses: [Course], webView: WKWebView) {
        result.courses = courses
        collectedAssignments = []
        collectedLectures = []
        collectedNotices = []
        processCourse(at: 0, courses: courses, webView: webView)
    }

    private func processCourse(at index: Int, courses: [Course], webView: WKWebView) {
        guard index < courses.count else {
            result.assignments = collectedAssignments.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            result.lectures = collectedLectures
            result.notices = collectedNotices.sorted { $0.dateText > $1.dateText }
            state = .finished
            return
        }

        let course = courses[index]
        state = .syncing("\(course.title) 강의실 확인 중...")

        loadHTML(course.url, webView: webView) { [weak self] courseHTML in
            guard let self = self else { return }
            var links = self.parser.parseActivityLinks(from: courseHTML)

            if links["assign"] == nil { links["assign"] = "https://learn.hansung.ac.kr/mod/assign/index.php?id=\(course.id)" }
            if links["vod"] == nil { links["vod"] = "https://learn.hansung.ac.kr/mod/vod/index.php?id=\(course.id)" }
            if links["progress"] == nil { links["progress"] = "https://learn.hansung.ac.kr/report/ubcompletion/user_progress_a.php?id=\(course.id)" }

            self.loadAssignments(course: course, links: links, webView: webView) {
                self.loadLectureProgress(course: course, links: links, webView: webView) {
                    self.loadNotices(course: course, links: links, webView: webView) {
                        self.processCourse(at: index + 1, courses: courses, webView: webView)
                    }
                }
            }
        }
    }

    private func loadAssignments(course: Course, links: [String: String], webView: WKWebView, completion: @escaping () -> Void) {
        guard let assignURL = links["assign"] else {
            completion()
            return
        }

        state = .syncing("\(course.title) 과제 목록 불러오는 중...")
        loadHTML(assignURL, webView: webView) { [weak self] html in
            guard let self = self else { return }
            self.collectedAssignments.append(contentsOf: self.parser.parseAssignments(from: html, courseName: course.title))
            completion()
        }
    }

    private func loadLectureProgress(course: Course, links: [String: String], webView: WKWebView, completion: @escaping () -> Void) {
        guard let progressURL = links["progress"] else {
            completion()
            return
        }

        state = .syncing("\(course.title) 동영상 출석 상태 확인 중...")
        loadHTML(progressURL, webView: webView) { [weak self] html in
            guard let self = self else { return }
            self.collectedLectures.append(contentsOf: self.parser.parseLectureProgress(from: html, courseName: course.title))
            completion()
        }
    }

    private func loadNotices(course: Course, links: [String: String], webView: WKWebView, completion: @escaping () -> Void) {
        guard let boardURL = links["board"] else {
            completion()
            return
        }

        state = .syncing("\(course.title) 공지사항 가져오는 중...")
        loadHTML(boardURL, webView: webView) { [weak self] html in
            guard let self = self else { return }
            let notices = self.parser.parseNotices(from: html, courseName: course.title)
            self.loadNoticeDetails(notices: notices, index: 0, webView: webView, courseTitle: course.title) { detailed in
                self.collectedNotices.append(contentsOf: detailed)
                completion()
            }
        }
    }

    private func loadNoticeDetails(notices: [NoticeItem], index: Int, webView: WKWebView, courseTitle: String, completion: @escaping ([NoticeItem]) -> Void) {
        guard index < notices.count else {
            completion(notices)
            return
        }

        var updated = notices
        let notice = notices[index]
        guard !notice.url.isEmpty else {
            loadNoticeDetails(notices: updated, index: index + 1, webView: webView, courseTitle: courseTitle, completion: completion)
            return
        }

        state = .syncing("\(courseTitle) 공지 내용 확인 중...")
        loadHTML(notice.url, webView: webView) { [weak self] html in
            guard let self = self else { return }
            if let detail = self.parser.parseNoticeDetail(from: html) {
                updated[index].content = detail.content
            }
            self.loadNoticeDetails(notices: updated, index: index + 1, webView: webView, courseTitle: courseTitle, completion: completion)
        }
    }

    private func loadHTML(_ urlString: String, webView: WKWebView, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString) else {
            completion("")
            return
        }

        let loader = PageLoadWaiter(webView: webView) { [weak self] in
            self?.evaluateHTML(webView) { html in
                completion(html)
            }
        }
        PageLoadWaiterStore.shared.retain(loader)
        loader.onFinish = {
            PageLoadWaiterStore.shared.release(loader)
        }
        webView.navigationDelegate = loader
        webView.load(URLRequest(url: url))
    }

    private func evaluateHTML(_ webView: WKWebView, completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { result, _ in
            completion(result as? String ?? "")
        }
    }
}

private final class PageLoadWaiter: NSObject, WKNavigationDelegate {
    private let completion: () -> Void
    var onFinish: (() -> Void)?

    init(webView: WKWebView, completion: @escaping () -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.completion()
            self?.onFinish?()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion()
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion()
        onFinish?()
    }
}

private final class PageLoadWaiterStore {
    static let shared = PageLoadWaiterStore()
    private var waiters: [ObjectIdentifier: PageLoadWaiter] = [:]

    func retain(_ waiter: PageLoadWaiter) {
        waiters[ObjectIdentifier(waiter)] = waiter
    }

    func release(_ waiter: PageLoadWaiter) {
        waiters.removeValue(forKey: ObjectIdentifier(waiter))
    }
}
