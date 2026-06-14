import SwiftUI
import UIKit

struct DashboardView: View {
    let result: SyncResult
    let onLogout: () -> Void

    @State private var selectedMainTab = 0

    private var pendingAssignments: [AssignmentItem] {
        result.assignments.filter { !$0.isSubmitted }
    }

    private var missedLectures: [LectureProgressItem] {
        result.lectures.filter { !$0.isAttended }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HeaderView()

                        HStack(spacing: 10) {
                            MainTabButton(title: "대시보드", isSelected: selectedMainTab == 0) {
                                selectedMainTab = 0
                            }
                            MainTabButton(title: "강의", isSelected: selectedMainTab == 1) {
                                selectedMainTab = 1
                            }
                        }
                        .padding(.horizontal, 20)

                        if selectedMainTab == 0 {
                            DashboardTabView(
                                result: result,
                                pendingAssignments: pendingAssignments,
                                missedLectures: missedLectures
                            )
                        } else {
                            CourseListView(result: result)
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("안녕하세요! 👋")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(AppColors.text)
            Text("오늘도 화이팅이에요!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.subText)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }
}

struct MainTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSelected ? .white : AppColors.subText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isSelected ? AppColors.blue : Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03), radius: 8, x: 0, y: 4)
        }
    }
}

struct DashboardTabView: View {
    let result: SyncResult
    let pendingAssignments: [AssignmentItem]
    let missedLectures: [LectureProgressItem]

    private var recentNotices: [NoticeItem] {
        Array(result.notices.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                MiniSummaryCard(title: "미제출 과제", value: "\(pendingAssignments.count)", color: AppColors.orange, icon: "doc.text")
                MiniSummaryCard(title: "미수강 강의", value: "\(missedLectures.count)", color: AppColors.green, icon: "play.rectangle")
                MiniSummaryCard(title: "최근 공지", value: "\(result.notices.count)", color: AppColors.purple, icon: "megaphone")
            }
            .padding(.horizontal, 20)

            DashboardSection(title: "마감 과제") {
                if pendingAssignments.isEmpty {
                    EmptyStateCard(text: "표시할 과제가 없습니다.", detail: "현재 미제출 과제가 없어요.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(pendingAssignments.prefix(5))) { item in
                            AssignmentRow(item: item, compact: true)
                        }
                    }
                }
            }

            DashboardSection(title: "미수강 동영상") {
                if missedLectures.isEmpty {
                    EmptyStateCard(text: "미수강 강의가 없습니다.", detail: "모든 강의를 수강했어요.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(missedLectures.prefix(5))) { item in
                            LectureRow(item: item)
                        }
                    }
                }
            }

            DashboardSection(title: "최근 공지사항") {
                if recentNotices.isEmpty {
                    EmptyStateCard(text: "공지사항이 없습니다.", detail: "최근 등록된 공지가 없어요.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(recentNotices) { notice in
                            NavigationLink(destination: NoticeDetailView(notice: notice)) {
                                NoticeRow(notice: notice)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

struct CourseListView: View {
    let result: SyncResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("수강 강의")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.text)
                .padding(.horizontal, 20)

            if result.courses.isEmpty {
                EmptyStateCard(text: "수강 강좌가 없습니다.", detail: "로그인 후 다시 확인해주세요.")
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 14) {
                    ForEach(result.courses.indices, id: \.self) { index in
                        let course = result.courses[index]
                        NavigationLink(destination: CourseDetailView(course: course, result: result, color: AppColors.courseColor(index: index))) {
                            CourseCard(
                                course: course,
                                color: AppColors.courseColor(index: index),
                                assignmentCount: result.assignments(for: course).filter { !$0.isSubmitted }.count,
                                noticeCount: result.notices(for: course).count,
                                lectureCount: result.lectures(for: course).filter { !$0.isAttended }.count
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct DashboardSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.text)
            content()
        }
        .padding(.horizontal, 20)
    }
}

struct MiniSummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                )
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.text)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.subText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 9, x: 0, y: 4)
    }
}

struct CourseCard: View {
    let course: Course
    let color: Color
    let assignmentCount: Int
    let noticeCount: Int
    let lectureCount: Int

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.16))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(courseAbbreviation(course.title))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                        .minimumScaleFactor(0.6)
                        .padding(4)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(course.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    InfoPill(text: "과제 \(assignmentCount)개", color: AppColors.orange)
                    InfoPill(text: "공지 \(noticeCount)개", color: AppColors.purple)
                }
                InfoPill(text: "미수강 강의 \(lectureCount)개", color: AppColors.green)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.subText.opacity(0.7))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct InfoPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(10)
    }
}

struct AssignmentRow: View {
    let item: AssignmentItem
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.orange.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "doc.text").foregroundColor(AppColors.orange))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(compact ? 2 : nil)
                Text(item.courseName)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
                Text("마감: \(item.dueDateText) · \(item.submitStatus)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.subText)
            }

            Spacer()

            Text(item.dDayText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(item.isOverdue ? AppColors.red : AppColors.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((item.isOverdue ? AppColors.red : AppColors.blue).opacity(0.12))
                .cornerRadius(10)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
    }
}

struct LectureRow: View {
    let item: LectureProgressItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.green.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "play.rectangle").foregroundColor(AppColors.green))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)
                Text("\(item.courseName) · \(item.week)주차")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
                Text("요구시간 \(item.requiredTime) · 학습시간 \(item.learnedTime)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.subText)
            }

            Spacer()

            Text(item.isAttended ? "완료" : "미수강")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(item.isAttended ? AppColors.green : AppColors.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((item.isAttended ? AppColors.green : AppColors.red).opacity(0.12))
                .cornerRadius(10)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
    }
}

struct NoticeRow: View {
    let notice: NoticeItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.purple.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "megaphone").foregroundColor(AppColors.purple))

            VStack(alignment: .leading, spacing: 5) {
                Text(notice.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)
                Text("\(notice.courseName) · \(notice.dateText)")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
                Text(notice.previewText)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
    }
}

struct EmptyStateCard: View {
    let text: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.text)
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(AppColors.subText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
    }
}

struct CourseDetailView: View {
    let course: Course
    let result: SyncResult
    let color: Color

    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedTab = 0

    private var assignments: [AssignmentItem] { result.assignments(for: course) }
    private var notices: [NoticeItem] { result.notices(for: course) }
    private var lectures: [LectureProgressItem] { result.lectures(for: course) }

    var body: some View {
        ZStack {
            AppColors.background.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DetailHeader(course: course, color: color) {
                        presentationMode.wrappedValue.dismiss()
                    }

                    HStack(spacing: 10) {
                        DetailTabButton(title: "과제", isSelected: selectedTab == 0, color: color) { selectedTab = 0 }
                        DetailTabButton(title: "공지", isSelected: selectedTab == 1, color: color) { selectedTab = 1 }
                        DetailTabButton(title: "동영상", isSelected: selectedTab == 2, color: color) { selectedTab = 2 }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        if selectedTab == 0 {
                            if assignments.isEmpty {
                                EmptyStateCard(text: "표시할 과제가 없습니다.", detail: "등록된 과제가 없어요.")
                            } else {
                                ForEach(assignments) { item in AssignmentRow(item: item, compact: false) }
                            }
                        } else if selectedTab == 1 {
                            if notices.isEmpty {
                                EmptyStateCard(text: "공지사항이 없습니다.", detail: "이 과목에 등록된 공지가 없어요.")
                            } else {
                                ForEach(notices) { notice in
                                    NavigationLink(destination: NoticeDetailView(notice: notice)) {
                                        NoticeRow(notice: notice)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
                            if lectures.isEmpty {
                                EmptyStateCard(text: "동영상 정보가 없습니다.", detail: "온라인출석부에서 확인된 항목이 없어요.")
                            } else {
                                ForEach(lectures) { item in LectureRow(item: item) }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct DetailHeader: View {
    let course: Course
    let color: Color
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("뒤로가기")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.text)
            }

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.16))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(courseAbbreviation(course.title))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(color)
                            .minimumScaleFactor(0.6)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(course.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(AppColors.text)
                    if let professor = course.professor, !professor.isEmpty {
                        Text(professor)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.subText)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }
}

struct DetailTabButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : AppColors.subText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? color : Color.white)
                .cornerRadius(14)
        }
    }
}

struct NoticeDetailView: View {
    let notice: NoticeItem
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            AppColors.background.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("뒤로가기")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.text)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(notice.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.text)
                        Text("\(notice.courseName) · \(notice.writer)")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.subText)
                        Text("작성일: \(notice.dateText) · 조회수: \(notice.hits)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.subText)
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("공지 내용")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.text)
                        Text((notice.content ?? "").isEmpty ? "공지 내용을 불러오지 못했습니다." : (notice.content ?? ""))
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.text)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                }
                .padding(20)
            }
        }
        .navigationBarHidden(true)
    }
}

func courseAbbreviation(_ title: String) -> String {
    let lower = title.lowercased()
    if lower.contains("ios") { return "iOS" }
    if title.contains("정보보안") || lower.contains("security") { return "SEC" }
    if title.contains("웹") || lower.contains("web") { return "WEB" }
    if title.contains("영어") || lower.contains("english") { return "ENG" }
    if title.contains("캡스톤") { return "CAP" }

    let words = title
        .replacingOccurrences(of: "[", with: " ")
        .replacingOccurrences(of: "]", with: " ")
        .split(separator: " ")
    if let first = words.first {
        let text = String(first)
        if text.count >= 3 { return String(text.prefix(3)) }
        return text
    }
    return "CLS"
}

struct AppColors {
    static let background = Color(red: 0.96, green: 0.98, blue: 1.0)
    static let text = Color(red: 0.08, green: 0.10, blue: 0.16)
    static let subText = Color(red: 0.42, green: 0.46, blue: 0.55)

    static let blue = Color(hex: 0x3B82F6)
    static let green = Color(hex: 0x22C55E)
    static let purple = Color(hex: 0x8B5CF6)
    static let orange = Color(hex: 0xF97316)
    static let mint = Color(hex: 0x14B8A6)
    static let pink = Color(hex: 0xEC4899)
    static let navy = Color(hex: 0x1D4ED8)
    static let yellow = Color(hex: 0xEAB308)
    static let cyan = Color(hex: 0x06B6D4)
    static let red = Color(hex: 0xEF4444)

    static func courseColor(index: Int) -> Color {
        let colors = [blue, green, purple, orange, mint, pink, navy, yellow, cyan, red]
        return colors[index % colors.count]
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0
        )
    }
}
