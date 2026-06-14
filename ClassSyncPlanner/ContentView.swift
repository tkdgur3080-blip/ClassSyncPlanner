import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var syncManager = EclassSyncManager()

    var body: some View {
        Group {
            switch syncManager.state {
            case .welcome:
                WelcomeView {
                    syncManager.beginLogin()
                }
            case .loginRequired:
                LoginContainerView(syncManager: syncManager) {
                    syncManager.resetToStart()
                }
            case .syncing(let message):
                LoadingView(message: message)
            case .finished:
                DashboardView(result: syncManager.result) {
                    syncManager.resetToStart()
                }
            case .failed(let message):
                FailureView(message: message) {
                    syncManager.resetToStart()
                }
            }
        }
    }
}

struct WelcomeView: View {
    let onLogin: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.edgesIgnoringSafeArea(.all)
            VStack(spacing: 26) {
                Spacer()

                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(AppColors.blue)
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 34))
                                .foregroundColor(.white)
                        )

                    Text("ClassSync Planner")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AppColors.text)

                    Text("Eclass 과제, 공지, 강의 정보를\n한눈에 확인하세요.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.subText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 14) {
                    FeatureCard(icon: "doc.text", title: "과제 확인", subtitle: "마감일과 제출 상태를 정리해 보여줍니다.", color: AppColors.orange)
                    FeatureCard(icon: "megaphone", title: "공지 확인", subtitle: "최근 공지와 상세 내용을 앱에서 확인합니다.", color: AppColors.purple)
                    FeatureCard(icon: "play.rectangle", title: "강의 출석", subtitle: "미수강 강의와 출석 상태를 확인합니다.", color: AppColors.green)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onLogin) {
                    Text("Eclass 로그인하기")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.blue)
                        .cornerRadius(18)
                }
                .padding(.horizontal, 24)

                Text("로그인 정보는 저장하지 않고 공식 Eclass 페이지를 통해 로그인합니다.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.16))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 22, weight: .semibold))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.subText)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct LoginContainerView: View {
    @ObservedObject var syncManager: EclassSyncManager
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.text)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Eclass 로그인")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Text("공식 Eclass 페이지에서 로그인해주세요")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.subText)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.background)

            EclassLoginWebView(syncManager: syncManager)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

struct LoadingView: View {
    let message: String

    var body: some View {
        ZStack {
            AppColors.background.edgesIgnoringSafeArea(.all)
            VStack(spacing: 22) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(AppColors.blue.opacity(0.12))
                    .frame(width: 84, height: 84)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.25)
                    )

                VStack(spacing: 8) {
                    Text("대시보드 정리 중")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.subText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }

                VStack(alignment: .leading, spacing: 12) {
                    LoadingStep(text: "수강 강좌 확인")
                    LoadingStep(text: "과제 목록 불러오기")
                    LoadingStep(text: "최근 공지사항 가져오기")
                    LoadingStep(text: "동영상 출석 상태 확인")
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 32)
            }
        }
    }
}

struct LoadingStep: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppColors.blue.opacity(0.18))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.blue)
                )
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.text)
            Spacer()
        }
    }
}

struct FailureView: View {
    let message: String
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.edgesIgnoringSafeArea(.all)
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.red)
                Text("정보를 불러오지 못했습니다")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(AppColors.text)
                Text(message.isEmpty ? "네트워크 상태를 확인한 뒤 다시 로그인해주세요." : message)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.subText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button(action: onRestart) {
                    Text("처음으로")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(AppColors.blue)
                        .cornerRadius(16)
                }
            }
        }
    }
}
