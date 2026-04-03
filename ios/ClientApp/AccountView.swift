import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var session: AppSession

    private var userName: String {
        session.user?.displayName ?? "Photo G Member"
    }

    private var secondaryIdentity: String {
        session.user?.email ?? "Signed in with Apple"
    }

    private var accessTitle: String {
        if session.entitlement?.isActive == true {
            return session.entitlement?.tierName ?? "Creator Access"
        }
        return "Standard Plan"
    }

    private var accessDescription: String {
        session.entitlement?.usageDescription
            ?? "Manage your subscription, saved work, and account details from one place."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        profileCard
                        accessCard
                        appSnapshotCard
                        supportCard
                        actionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await session.refreshSessionData()
            }
        }
    }

    private var profileCard: some View {
        StudioSurface {
            HStack(alignment: .top, spacing: 16) {
                StudioMarkView(size: 74)

                VStack(alignment: .leading, spacing: 10) {
                    StudioStatusBadge(
                        icon: "person.crop.circle.fill",
                        title: "PhotoG profile",
                        tint: Color("AccentColor")
                    )

                    Text(userName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(secondaryIdentity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        StudioSummaryCard(value: "\(session.catalog.count)", label: "tools")
                        StudioSummaryCard(value: "\(session.jobs.count)", label: "runs")
                        StudioSummaryCard(value: "\(session.localAssets.count)", label: "saved")
                    }
                }
            }
        }
    }

    private var accessCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Subscription",
                    title: accessTitle,
                    detail: accessDescription
                )

                HStack(spacing: 12) {
                    StudioSummaryCard(
                        value: session.entitlement?.isActive == true ? "Active" : "Ready",
                        label: "status",
                        tint: session.entitlement?.isActive == true ? Color.green : Color("AccentColor")
                    )

                    StudioSummaryCard(
                        value: renewalLabel,
                        label: "renews",
                        tint: Color("AccentColor")
                    )
                }

                if let managementURL = session.entitlement?.managementURL ?? session.appConfig.subscriptionManagementURL {
                    Link(destination: managementURL) {
                        HStack {
                            Text("Manage plan")
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundStyle(Color("AccentColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private var appSnapshotCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Workspace",
                    title: "Current app setup"
                )

                VStack(spacing: 12) {
                    AccountInfoRow(title: "Version", value: versionLabel)
                    AccountInfoRow(title: "Saved outputs folder", value: LocalAssetStore.directoryURL.lastPathComponent)
                    AccountInfoRow(title: "Featured tools", value: "\(session.appConfig.featuredModelIds.count)")
                }
            }
        }
    }

    private var supportCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeader(
                    eyebrow: "Support",
                    title: "Help and policies"
                )

                VStack(spacing: 12) {
                    if let privacyURL = session.appConfig.privacyURL {
                        AccountLinkRow(title: "Privacy policy", destination: privacyURL)
                    }

                    if let termsURL = session.appConfig.termsURL {
                        AccountLinkRow(title: "Terms of service", destination: termsURL)
                    }

                    if let supportEmail = session.appConfig.supportEmail,
                       let supportURL = URL(string: "mailto:\(supportEmail)")
                    {
                        AccountLinkRow(title: "Email support", destination: supportURL)
                    }
                }
            }
        }
    }

    private var actionCard: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    Task { await session.refreshSessionData() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Refresh profile", systemImage: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color("AccentColor"), Color(red: 0.98, green: 0.71, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var renewalLabel: String {
        guard let renewalDate = session.entitlement?.renewalDate,
              let date = ISO8601DateFormatter().date(from: renewalDate)
        else {
            return "TBD"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct AccountInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AccountLinkRow: View {
    let title: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.studioPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
