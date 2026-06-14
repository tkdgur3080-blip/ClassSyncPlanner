import Foundation

final class HTMLParser {
    static let shared = HTMLParser()
    private init() {}

    func parseCourses(from html: String) -> [Course] {
        let pattern = #"<a[^>]*href=[\"']([^\"']*course/view\.php\?id=(\d+)[^\"']*)[\"'][^>]*class=[\"'][^\"']*course_link[^\"']*[\"'][^>]*>([\s\S]*?)</a>"#
        return matches(pattern: pattern, in: html).compactMap { match in
            guard match.count >= 4 else { return nil }
            let url = decodeHTML(match[1])
            let courseId = match[2]
            let inner = match[3]
            let title = firstMatch(#"<h3[^>]*>([\s\S]*?)</h3>"#, in: inner).map(cleanText) ?? cleanText(inner)
            let professor = firstMatch(#"<p[^>]*class=[\"'][^\"']*prof[^\"']*[\"'][^>]*>([\s\S]*?)</p>"#, in: inner).map(cleanText)
            guard !title.isEmpty else { return nil }
            return Course(id: courseId, title: title, professor: professor, url: absoluteURL(url, base: "https://learn.hansung.ac.kr"))
        }.uniqueById()
    }

    func parseActivityLinks(from html: String) -> [String: String] {
        var result: [String: String] = [:]
        let linkPattern = #"<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\s\S]*?)</a>"#
        for m in matches(pattern: linkPattern, in: html) where m.count >= 3 {
            let href = absoluteURL(decodeHTML(m[1]), base: "https://learn.hansung.ac.kr")
            let title = cleanText(m[2])

            if href.contains("/mod/assign/index.php") || title == "과제" { result["assign"] = href }
            if href.contains("/mod/vod/index.php") || title == "동영상" { result["vod"] = href }
            if href.contains("/report/ubcompletion/") || title == "온라인출석부" { result["progress"] = href }

            // 공지사항은 Q&A/자유게시판과 섞이지 않도록 링크 텍스트가 공지사항인 게시판만 사용한다.
            if href.contains("/mod/ubboard/view.php") && title.contains("공지사항") && !title.contains("Q") {
                result["board"] = href
            }
        }
        return result
    }

    func parseAssignments(from html: String, courseName: String) -> [AssignmentItem] {
        guard let table = firstMatch(#"<table[^>]*class=[\"'][^\"']*generaltable[^\"']*[\"'][^>]*>([\s\S]*?)</table>"#, in: html) else { return [] }
        let rows = matches(pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#, in: table)
        return rows.compactMap { rowMatch in
            let row = rowMatch[1]
            let cells = matches(pattern: #"<td[^>]*class=[\"'][^\"']*cell[^\"']*[\"'][^>]*>([\s\S]*?)</td>"#, in: row).map { $0[1] }
            guard cells.count >= 5 else { return nil }
            let link = firstLink(in: cells[1])
            let title = link.title.isEmpty ? cleanText(cells[1]) : link.title
            guard !title.isEmpty else { return nil }
            return AssignmentItem(
                courseName: courseName,
                week: cleanText(cells[0]),
                title: title,
                url: absoluteURL(link.href, base: "https://learn.hansung.ac.kr/mod/assign/"),
                dueDateText: cleanText(cells[2]),
                submitStatus: cleanText(cells[3]),
                grade: cleanText(cells[4])
            )
        }
    }

    func parseLectureProgress(from html: String, courseName: String) -> [LectureProgressItem] {
        guard let table = firstMatch(#"<table[^>]*class=[\"'][^\"']*user_progress_table[^\"']*[\"'][^>]*>([\s\S]*?)</table>"#, in: html) else { return [] }
        var lastWeek = ""
        let rows = matches(pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#, in: table)
        return rows.compactMap { rowMatch in
            let row = rowMatch[1]
            let cells = matches(pattern: #"<td[^>]*>([\s\S]*?)</td>"#, in: row).map { $0[1] }
            guard cells.count >= 5 else { return nil }
            let firstCell = cleanText(cells[0])
            let hasRowspanWeek = row.contains("rowspan") && !firstCell.isEmpty
            if hasRowspanWeek { lastWeek = firstCell }

            let titleCellIndex = hasRowspanWeek ? 1 : 0
            guard cells.indices.contains(titleCellIndex + 3) else { return nil }
            let title = cleanText(cells[titleCellIndex]).replacingOccurrences(of: "&nbsp;", with: "")
            guard !title.isEmpty else { return nil }

            let required = cells.indices.contains(titleCellIndex + 1) ? cleanText(cells[titleCellIndex + 1]) : ""
            let learnedRaw = cells.indices.contains(titleCellIndex + 2) ? cleanTextBeforeButton(cells[titleCellIndex + 2]) : ""
            let attendance = cells.indices.contains(titleCellIndex + 3) ? cleanText(cells[titleCellIndex + 3]) : ""
            let weekly = cells.indices.contains(titleCellIndex + 4) ? cleanText(cells[titleCellIndex + 4]) : ""

            guard attendance == "O" || attendance == "X" else { return nil }
            return LectureProgressItem(
                courseName: courseName,
                week: lastWeek,
                title: title,
                requiredTime: required,
                learnedTime: learnedRaw,
                attendance: attendance,
                weeklyAttendance: weekly
            )
        }
    }

    func parseNotices(from html: String, courseName: String) -> [NoticeItem] {
        guard let table = firstMatch(#"<table[^>]*class=[\"'][^\"']*ubboard_table[^\"']*[\"'][^>]*>([\s\S]*?)</table>"#, in: html) else { return [] }
        let rows = matches(pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#, in: table)
        return rows.compactMap { rowMatch in
            let row = rowMatch[1]
            let cells = matches(pattern: #"<td[^>]*>([\s\S]*?)</td>"#, in: row).map { $0[1] }
            guard cells.count >= 5 else { return nil }
            let link = firstLink(in: cells[1])
            let title = link.title.isEmpty ? cleanText(cells[1]) : link.title
            guard !title.isEmpty else { return nil }
            return NoticeItem(
                courseName: courseName,
                number: cleanText(cells[0]),
                title: title,
                url: absoluteURL(link.href, base: "https://learn.hansung.ac.kr/mod/ubboard/"),
                writer: cleanText(cells[2]),
                dateText: cleanText(cells[3]),
                hits: cleanText(cells[4])
            )
        }
    }

    func parseNoticeDetail(from html: String) -> (title: String, writer: String, date: String, hits: String, content: String)? {
        guard let view = firstMatch(#"<div[^>]*class=[\"'][^\"']*ubboard_view[^\"']*[\"'][^>]*>([\s\S]*?)</div>\s*</div>\s*</div>"#, in: html) ?? firstMatch(#"<div[^>]*class=[\"'][^\"']*ubboard_view[^\"']*[\"'][^>]*>([\s\S]*?)</div>"#, in: html) else { return nil }
        let title = firstMatch(#"<div[^>]*class=[\"']subject[\"'][^>]*>\s*<h3[^>]*>([\s\S]*?)</h3>"#, in: view).map(cleanText) ?? ""
        let writer = firstMatch(#"<div[^>]*class=[\"']writer[\"'][^>]*>([\s\S]*?)</div>"#, in: view).map { cleanText($0).replacingOccurrences(of: "작성자 :", with: "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let date = firstMatch(#"<div[^>]*class=[\"']date[\"'][^>]*>([\s\S]*?)</div>"#, in: view).map { cleanText($0).replacingOccurrences(of: "작성일 :", with: "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let hits = firstMatch(#"<div[^>]*class=[\"']hit[\"'][^>]*>([\s\S]*?)</div>"#, in: view).map { cleanText($0).replacingOccurrences(of: "조회수 :", with: "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let content = firstMatch(#"<div[^>]*class=[\"'][^\"']*text_to_html[^\"']*[\"'][^>]*>([\s\S]*?)</div>"#, in: view).map(cleanText) ?? ""
        return (title, writer, date, hits, content)
    }

    private func firstLink(in html: String) -> (href: String, title: String) {
        guard let m = matches(pattern: #"<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\s\S]*?)</a>"#, in: html).first, m.count >= 3 else {
            return ("", "")
        }
        return (decodeHTML(m[1]), cleanText(m[2]))
    }

    private func cleanTextBeforeButton(_ html: String) -> String {
        let beforeButton = html.components(separatedBy: "<button").first ?? html
        return cleanText(beforeButton)
    }

    private func firstMatch(_ pattern: String, in html: String) -> String? {
        matches(pattern: pattern, in: html).first?.dropFirst().first
    }

    private func matches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)).map { match in
            (0..<match.numberOfRanges).compactMap { idx in
                let range = match.range(at: idx)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
        }
    }

    private func cleanText(_ html: String) -> String {
        let withBreaks = html
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "</div>", with: "\n")
        let noTags = withBreaks.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return decodeHTML(noTags)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private func absoluteURL(_ href: String, base: String) -> String {
        guard !href.isEmpty else { return href }
        if href.hasPrefix("http") { return href }
        if href.hasPrefix("/") { return "https://learn.hansung.ac.kr" + href }
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + href
    }
}

private extension Array where Element == Course {
    func uniqueById() -> [Course] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
