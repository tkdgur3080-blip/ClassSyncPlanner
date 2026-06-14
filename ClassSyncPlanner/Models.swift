import Foundation

struct Course: Identifiable, Hashable {
    let id: String
    let title: String
    let professor: String?
    let url: String
}

struct AssignmentItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let week: String
    let title: String
    let url: String
    let dueDateText: String
    let submitStatus: String
    let grade: String

    var isSubmitted: Bool {
        submitStatus.contains("제출 완료") || submitStatus.contains("제출완료") || submitStatus.lowercased().contains("submitted")
    }

    var dueDate: Date? {
        DateFormatter.eclassDate.date(from: dueDateText)
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date()
    }

    var dDayText: String {
        guard let dueDate = dueDate else { return dueDateText }
        if dueDate < Date() { return "마감 지남" }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        let day = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
        if day == 0 { return "D-Day" }
        return "D-\(day)"
    }
}

struct LectureProgressItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let week: String
    let title: String
    let requiredTime: String
    let learnedTime: String
    let attendance: String
    let weeklyAttendance: String

    var isAttended: Bool {
        attendance.trimmingCharacters(in: .whitespacesAndNewlines) == "O"
    }
}

struct NoticeItem: Identifiable, Hashable {
    let id = UUID()
    let courseName: String
    let number: String
    let title: String
    let url: String
    let writer: String
    let dateText: String
    let hits: String
    var content: String? = nil

    var previewText: String {
        let text = (content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "공지 내용을 확인해보세요." }
        if text.count > 80 { return String(text.prefix(80)) + "..." }
        return text
    }
}

struct SyncResult {
    var courses: [Course] = []
    var assignments: [AssignmentItem] = []
    var lectures: [LectureProgressItem] = []
    var notices: [NoticeItem] = []

    func assignments(for course: Course) -> [AssignmentItem] {
        assignments.filter { $0.courseName == course.title }
    }

    func lectures(for course: Course) -> [LectureProgressItem] {
        lectures.filter { $0.courseName == course.title }
    }

    func notices(for course: Course) -> [NoticeItem] {
        notices.filter { $0.courseName == course.title }
    }
}

extension DateFormatter {
    static let eclassDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}
