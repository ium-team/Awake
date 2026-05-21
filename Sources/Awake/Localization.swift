import Foundation

struct L10n {
    let language: AppLanguage

    func text(_ key: Key) -> String {
        Self.localizedStrings[language.effectiveCode]?[key.rawValue]
            ?? Self.localizedStrings["en"]?[key.rawValue]
            ?? key.rawValue
    }

    func format(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language.effectiveCode), arguments: arguments)
    }

    func selectedFooter(count: Int) -> String {
        count == 0 ? text(.selectOneOrMoreApps) : format(.selectedAppsFooter, count)
    }

    func keepingApps(count: Int) -> String {
        if language.effectiveCode == "en" {
            return "Keeping \(count) app\(count == 1 ? "" : "s") awake"
        }
        return format(.keepingAppsAwake, count)
    }

    func duration(minutes: Int) -> String {
        if minutes < 60 {
            return format(.durationMinutes, minutes)
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            if language.effectiveCode == "en" {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
            return format(.durationHours, hours)
        }

        return format(.durationHoursMinutes, hours, remainingMinutes)
    }

    func languageDisplayName(_ appLanguage: AppLanguage) -> String {
        switch appLanguage {
        case .system:
            return text(.languageSystem)
        case .ko:
            return text(.languageKorean)
        case .zhHans:
            return text(.languageChinese)
        case .ja:
            return text(.languageJapanese)
        case .en:
            return text(.languageEnglish)
        }
    }

    enum Key: String {
        case keepAppsAwakeTitle
        case keepAppsAwakeSubtitle
        case searchApps
        case refresh
        case refreshAppList
        case start
        case selectOneOrMoreApps
        case selectedAppsFooter
        case shortcutCommandShiftA
        case keepingAppsAwake
        case stopKeepingAwake
        case tryAgain
        case settings
        case restoreMacOSSleep
        case quitAwake
        case awakeSettings
        case ok
        case couldNotRestoreMacOSSleep
        case couldNotUpdateLaunchAtLogin
        case launchAtLoginErrorBody
        case couldNotUpdateLidClosedHelper
        case general
        case language
        case languagePickerDescription
        case languageSystem
        case languageKorean
        case languageChinese
        case languageJapanese
        case languageEnglish
        case keepMacAwakeWhenLidClosed
        case lockScreenWhenLidCloses
        case noSafetyTimeLimit
        case safetyTimeLimit
        case stopIfBatteryDropsBelow
        case notifyWhenSessionEnds
        case lidClosedModeNotice
        case startup
        case openAwakeAtLogin
        case advanced
        case troubleshooting
        case preventDisplaySleep
        case useClosedDisplayNetworkSupport
        case repairHelper
        case uninstallHelper
        case helperRepaired
        case helperUninstalled
        case helper
        case ready
        case needsRepair
        case sleepDisabled
        case on
        case off
        case lid
        case closed
        case open
        case battery
        case powerSource
        case unknown
        case diagnosticsUnavailable
        case durationMinutes
        case durationHours
        case durationHoursMinutes
        case awakeStopped
        case selectedAppFinished
        case allSelectedAppsFinished
        case awakeRestoredMacOSSleep
        case safetyTimeLimitReached
        case batteryReached
    }

    private static let localizedStrings: [String: [String: String]] = [
        "en": [
            "keepAppsAwakeTitle": "Keep Apps Awake",
            "keepAppsAwakeSubtitle": "Select apps to keep awake until their processes finish.",
            "searchApps": "Search apps",
            "refresh": "Refresh",
            "refreshAppList": "Refresh app list",
            "start": "Start",
            "selectOneOrMoreApps": "Select one or more apps.",
            "selectedAppsFooter": "%d selected. Awake stops when all selected apps quit.",
            "shortcutCommandShiftA": "Shortcut: Command-Shift-A",
            "keepingAppsAwake": "Keeping %d apps awake",
            "stopKeepingAwake": "Stop Keeping Awake",
            "tryAgain": "Try Again...",
            "settings": "Settings...",
            "restoreMacOSSleep": "Restore macOS Sleep",
            "quitAwake": "Quit Awake",
            "awakeSettings": "Awake Settings",
            "ok": "OK",
            "couldNotRestoreMacOSSleep": "Could not restore macOS sleep",
            "couldNotUpdateLaunchAtLogin": "Could not update launch at login",
            "launchAtLoginErrorBody": "Open Awake from the app bundle and try again. macOS returned: %@",
            "couldNotUpdateLidClosedHelper": "Could not update lid-closed helper",
            "general": "General",
            "language": "Language",
            "languagePickerDescription": "Default follows your macOS language.",
            "languageSystem": "System Default",
            "languageKorean": "Korean",
            "languageChinese": "Chinese",
            "languageJapanese": "Japanese",
            "languageEnglish": "English",
            "keepMacAwakeWhenLidClosed": "Keep Mac awake when the lid is closed",
            "lockScreenWhenLidCloses": "Lock screen when lid closes",
            "noSafetyTimeLimit": "No safety time limit",
            "safetyTimeLimit": "Safety time limit: %@",
            "stopIfBatteryDropsBelow": "Stop if battery drops below %d%%",
            "notifyWhenSessionEnds": "Notify when session ends",
            "lidClosedModeNotice": "Lid-closed mode asks for administrator approval once. Awake restores normal sleep when the session ends. Do not use it in a bag or confined space.",
            "startup": "Startup",
            "openAwakeAtLogin": "Open Awake at login",
            "advanced": "Advanced",
            "troubleshooting": "Troubleshooting",
            "preventDisplaySleep": "Prevent display sleep during sessions",
            "useClosedDisplayNetworkSupport": "Use closed-display network support",
            "repairHelper": "Repair Helper",
            "uninstallHelper": "Uninstall Helper",
            "helperRepaired": "Helper repaired.",
            "helperUninstalled": "Helper uninstalled and macOS sleep restored.",
            "helper": "Helper",
            "ready": "Ready",
            "needsRepair": "Needs repair",
            "sleepDisabled": "SleepDisabled",
            "on": "On",
            "off": "Off",
            "lid": "Lid",
            "closed": "Closed",
            "open": "Open",
            "battery": "Battery",
            "powerSource": "Power Source",
            "unknown": "Unknown",
            "diagnosticsUnavailable": "Diagnostics are not available.",
            "durationMinutes": "%d minutes",
            "durationHours": "%d hours",
            "durationHoursMinutes": "%dh %dm",
            "awakeStopped": "Awake stopped",
            "selectedAppFinished": "The selected app finished, so Awake released the power assertion.",
            "allSelectedAppsFinished": "All selected apps finished, so Awake released the power assertion.",
            "awakeRestoredMacOSSleep": "Awake restored macOS sleep",
            "safetyTimeLimitReached": "Awake restored macOS sleep because the lid-closed session reached the configured time limit.",
            "batteryReached": "Awake restored macOS sleep because battery reached %d%%."
        ],
        "ko": [
            "keepAppsAwakeTitle": "앱 깨우기 유지",
            "keepAppsAwakeSubtitle": "프로세스가 끝날 때까지 Mac을 깨워 둘 앱을 선택하세요.",
            "searchApps": "앱 검색",
            "refresh": "새로고침",
            "refreshAppList": "앱 목록 새로고침",
            "start": "시작",
            "selectOneOrMoreApps": "하나 이상의 앱을 선택하세요.",
            "selectedAppsFooter": "%d개 선택됨. 선택한 앱이 모두 종료되면 Awake가 멈춥니다.",
            "shortcutCommandShiftA": "단축키: Command-Shift-A",
            "keepingAppsAwake": "%d개 앱 깨우기 유지 중",
            "stopKeepingAwake": "깨우기 유지 중지",
            "tryAgain": "다시 시도...",
            "settings": "설정...",
            "restoreMacOSSleep": "macOS 잠자기 복구",
            "quitAwake": "Awake 종료",
            "awakeSettings": "Awake 설정",
            "ok": "확인",
            "couldNotRestoreMacOSSleep": "macOS 잠자기를 복구할 수 없음",
            "couldNotUpdateLaunchAtLogin": "로그인 시 실행 설정을 업데이트할 수 없음",
            "launchAtLoginErrorBody": "앱 번들에서 Awake를 열고 다시 시도하세요. macOS 응답: %@",
            "couldNotUpdateLidClosedHelper": "덮개 닫힘 헬퍼를 업데이트할 수 없음",
            "general": "일반",
            "language": "언어",
            "languagePickerDescription": "기본값은 macOS 언어 설정을 따릅니다.",
            "languageSystem": "시스템 기본값",
            "languageKorean": "한국어",
            "languageChinese": "중국어",
            "languageJapanese": "일본어",
            "languageEnglish": "영어",
            "keepMacAwakeWhenLidClosed": "덮개가 닫혀도 Mac 깨우기 유지",
            "lockScreenWhenLidCloses": "덮개가 닫히면 화면 잠금",
            "noSafetyTimeLimit": "안전 시간 제한 없음",
            "safetyTimeLimit": "안전 시간 제한: %@",
            "stopIfBatteryDropsBelow": "배터리가 %d%% 아래로 내려가면 중지",
            "notifyWhenSessionEnds": "세션 종료 시 알림",
            "lidClosedModeNotice": "덮개 닫힘 모드는 최초 1회 관리자 승인을 요청합니다. Awake는 세션이 끝나면 일반 잠자기 설정을 복구합니다. 가방이나 밀폐된 공간에서는 사용하지 마세요.",
            "startup": "시작",
            "openAwakeAtLogin": "로그인 시 Awake 열기",
            "advanced": "고급",
            "troubleshooting": "문제 해결",
            "preventDisplaySleep": "세션 중 디스플레이 잠자기 방지",
            "useClosedDisplayNetworkSupport": "닫힌 디스플레이 네트워크 지원 사용",
            "repairHelper": "헬퍼 복구",
            "uninstallHelper": "헬퍼 제거",
            "helperRepaired": "헬퍼를 복구했습니다.",
            "helperUninstalled": "헬퍼를 제거했고 macOS 잠자기를 복구했습니다.",
            "helper": "헬퍼",
            "ready": "준비됨",
            "needsRepair": "복구 필요",
            "sleepDisabled": "잠자기 비활성화",
            "on": "켜짐",
            "off": "꺼짐",
            "lid": "덮개",
            "closed": "닫힘",
            "open": "열림",
            "battery": "배터리",
            "powerSource": "전원",
            "unknown": "알 수 없음",
            "diagnosticsUnavailable": "진단 정보를 사용할 수 없습니다.",
            "durationMinutes": "%d분",
            "durationHours": "%d시간",
            "durationHoursMinutes": "%d시간 %d분",
            "awakeStopped": "Awake 중지됨",
            "selectedAppFinished": "선택한 앱이 종료되어 Awake가 전원 assertion을 해제했습니다.",
            "allSelectedAppsFinished": "선택한 앱이 모두 종료되어 Awake가 전원 assertion을 해제했습니다.",
            "awakeRestoredMacOSSleep": "Awake가 macOS 잠자기를 복구했습니다",
            "safetyTimeLimitReached": "설정된 덮개 닫힘 세션 시간 제한에 도달해 Awake가 macOS 잠자기를 복구했습니다.",
            "batteryReached": "배터리가 %d%%에 도달해 Awake가 macOS 잠자기를 복구했습니다."
        ],
        "zh-Hans": [
            "keepAppsAwakeTitle": "保持应用唤醒",
            "keepAppsAwakeSubtitle": "选择要保持唤醒的应用，直到其进程结束。",
            "searchApps": "搜索应用",
            "refresh": "刷新",
            "refreshAppList": "刷新应用列表",
            "start": "开始",
            "selectOneOrMoreApps": "请选择一个或多个应用。",
            "selectedAppsFooter": "已选择 %d 个。所有选中应用退出后 Awake 会停止。",
            "shortcutCommandShiftA": "快捷键：Command-Shift-A",
            "keepingAppsAwake": "正在保持 %d 个应用唤醒",
            "stopKeepingAwake": "停止保持唤醒",
            "tryAgain": "重试...",
            "settings": "设置...",
            "restoreMacOSSleep": "恢复 macOS 睡眠",
            "quitAwake": "退出 Awake",
            "awakeSettings": "Awake 设置",
            "ok": "确定",
            "couldNotRestoreMacOSSleep": "无法恢复 macOS 睡眠",
            "couldNotUpdateLaunchAtLogin": "无法更新登录时启动",
            "launchAtLoginErrorBody": "请从应用包打开 Awake 后重试。macOS 返回：%@",
            "couldNotUpdateLidClosedHelper": "无法更新合盖辅助程序",
            "general": "通用",
            "language": "语言",
            "languagePickerDescription": "默认跟随 macOS 语言设置。",
            "languageSystem": "系统默认",
            "languageKorean": "韩语",
            "languageChinese": "中文",
            "languageJapanese": "日语",
            "languageEnglish": "英语",
            "keepMacAwakeWhenLidClosed": "合盖时保持 Mac 唤醒",
            "lockScreenWhenLidCloses": "合盖时锁定屏幕",
            "noSafetyTimeLimit": "无安全时间限制",
            "safetyTimeLimit": "安全时间限制：%@",
            "stopIfBatteryDropsBelow": "电量低于 %d%% 时停止",
            "notifyWhenSessionEnds": "会话结束时通知",
            "lidClosedModeNotice": "合盖模式首次会请求管理员批准。会话结束后 Awake 会恢复正常睡眠设置。请勿在包内或密闭空间使用。",
            "startup": "启动",
            "openAwakeAtLogin": "登录时打开 Awake",
            "advanced": "高级",
            "troubleshooting": "故障排除",
            "preventDisplaySleep": "会话期间阻止显示器睡眠",
            "useClosedDisplayNetworkSupport": "使用闭合显示器网络支持",
            "repairHelper": "修复辅助程序",
            "uninstallHelper": "卸载辅助程序",
            "helperRepaired": "辅助程序已修复。",
            "helperUninstalled": "辅助程序已卸载，macOS 睡眠已恢复。",
            "helper": "辅助程序",
            "ready": "就绪",
            "needsRepair": "需要修复",
            "sleepDisabled": "睡眠禁用",
            "on": "开启",
            "off": "关闭",
            "lid": "上盖",
            "closed": "已关闭",
            "open": "已打开",
            "battery": "电池",
            "powerSource": "电源",
            "unknown": "未知",
            "diagnosticsUnavailable": "诊断信息不可用。",
            "durationMinutes": "%d 分钟",
            "durationHours": "%d 小时",
            "durationHoursMinutes": "%d 小时 %d 分钟",
            "awakeStopped": "Awake 已停止",
            "selectedAppFinished": "选中的应用已结束，因此 Awake 已释放电源 assertion。",
            "allSelectedAppsFinished": "所有选中的应用已结束，因此 Awake 已释放电源 assertion。",
            "awakeRestoredMacOSSleep": "Awake 已恢复 macOS 睡眠",
            "safetyTimeLimitReached": "合盖会话已达到配置的时间限制，Awake 已恢复 macOS 睡眠。",
            "batteryReached": "电量已达到 %d%%，Awake 已恢复 macOS 睡眠。"
        ],
        "ja": [
            "keepAppsAwakeTitle": "アプリの起動を維持",
            "keepAppsAwakeSubtitle": "プロセスが終了するまでスリープを防ぐアプリを選択します。",
            "searchApps": "アプリを検索",
            "refresh": "更新",
            "refreshAppList": "アプリ一覧を更新",
            "start": "開始",
            "selectOneOrMoreApps": "1つ以上のアプリを選択してください。",
            "selectedAppsFooter": "%d個選択中。選択したすべてのアプリが終了すると Awake は停止します。",
            "shortcutCommandShiftA": "ショートカット: Command-Shift-A",
            "keepingAppsAwake": "%d個のアプリの起動を維持中",
            "stopKeepingAwake": "起動維持を停止",
            "tryAgain": "再試行...",
            "settings": "設定...",
            "restoreMacOSSleep": "macOS スリープを復元",
            "quitAwake": "Awake を終了",
            "awakeSettings": "Awake 設定",
            "ok": "OK",
            "couldNotRestoreMacOSSleep": "macOS スリープを復元できません",
            "couldNotUpdateLaunchAtLogin": "ログイン時に開く設定を更新できません",
            "launchAtLoginErrorBody": "アプリバンドルから Awake を開いて再試行してください。macOS の応答: %@",
            "couldNotUpdateLidClosedHelper": "蓋閉じヘルパーを更新できません",
            "general": "一般",
            "language": "言語",
            "languagePickerDescription": "デフォルトでは macOS の言語設定に従います。",
            "languageSystem": "システムデフォルト",
            "languageKorean": "韓国語",
            "languageChinese": "中国語",
            "languageJapanese": "日本語",
            "languageEnglish": "英語",
            "keepMacAwakeWhenLidClosed": "蓋を閉じても Mac の起動を維持",
            "lockScreenWhenLidCloses": "蓋を閉じたら画面をロック",
            "noSafetyTimeLimit": "安全時間制限なし",
            "safetyTimeLimit": "安全時間制限: %@",
            "stopIfBatteryDropsBelow": "バッテリーが %d%% 未満になったら停止",
            "notifyWhenSessionEnds": "セッション終了時に通知",
            "lidClosedModeNotice": "蓋閉じモードは初回のみ管理者承認を求めます。セッション終了時に Awake は通常のスリープ設定を復元します。バッグや密閉空間では使用しないでください。",
            "startup": "起動",
            "openAwakeAtLogin": "ログイン時に Awake を開く",
            "advanced": "詳細",
            "troubleshooting": "トラブルシューティング",
            "preventDisplaySleep": "セッション中のディスプレイスリープを防止",
            "useClosedDisplayNetworkSupport": "クローズドディスプレイのネットワーク支援を使用",
            "repairHelper": "ヘルパーを修復",
            "uninstallHelper": "ヘルパーをアンインストール",
            "helperRepaired": "ヘルパーを修復しました。",
            "helperUninstalled": "ヘルパーをアンインストールし、macOS スリープを復元しました。",
            "helper": "ヘルパー",
            "ready": "準備完了",
            "needsRepair": "修復が必要",
            "sleepDisabled": "スリープ無効",
            "on": "オン",
            "off": "オフ",
            "lid": "蓋",
            "closed": "閉じています",
            "open": "開いています",
            "battery": "バッテリー",
            "powerSource": "電源",
            "unknown": "不明",
            "diagnosticsUnavailable": "診断情報を利用できません。",
            "durationMinutes": "%d分",
            "durationHours": "%d時間",
            "durationHoursMinutes": "%d時間%d分",
            "awakeStopped": "Awake が停止しました",
            "selectedAppFinished": "選択したアプリが終了したため、Awake は電源 assertion を解放しました。",
            "allSelectedAppsFinished": "選択したすべてのアプリが終了したため、Awake は電源 assertion を解放しました。",
            "awakeRestoredMacOSSleep": "Awake が macOS スリープを復元しました",
            "safetyTimeLimitReached": "蓋閉じセッションが設定された時間制限に達したため、Awake は macOS スリープを復元しました。",
            "batteryReached": "バッテリーが %d%% に達したため、Awake は macOS スリープを復元しました。"
        ]
    ]
}
