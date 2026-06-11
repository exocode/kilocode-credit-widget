import Foundation

/// App-Sprache: live umschaltbar, im App-Group-Container gespeichert,
/// damit das Widget dieselbe Sprache nutzt.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"
    case spanish = "es"
    case chinese = "zh"
    case japanese = "ja"
    case russian = "ru"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .chinese: "中文"
        case .japanese: "日本語"
        case .russian: "Русский"
        }
    }

    /// Aufgelöste Übersetzungstabelle (System folgt der bevorzugten Sprache).
    var table: L10nTable {
        switch self {
        case .english: .en
        case .german: .de
        case .spanish: .es
        case .chinese: .zh
        case .japanese: .ja
        case .russian: .ru
        case .system: Self.systemResolved
        }
    }

    private static var systemResolved: L10nTable {
        for lang in Locale.preferredLanguages {
            if lang.hasPrefix("en") { return .en }
            if lang.hasPrefix("de") { return .de }
            if lang.hasPrefix("es") { return .es }
            if lang.hasPrefix("zh") { return .zh }
            if lang.hasPrefix("ja") { return .ja }
            if lang.hasPrefix("ru") { return .ru }
        }
        return .en
    }
}

enum L10n {
    /// Aktuell wirksame Tabelle (App und Widget).
    static var current: L10nTable {
        CreditCache.language.table
    }
}

struct L10nTable {
    // Menüleiste / Popover
    let refreshNow: String
    let statusHealthy: String
    let statusLow: String
    let statusCritical: String
    let updatedAt: String
    let loadingBalance: String
    let addCredits: String
    let settings: String
    let quit: String

    // Setup / Anmeldung
    let connectTitle: String
    let connectBody: String
    let signInWithBrowser: String
    let waitingForBrowser: String
    let codeLabel: String
    let cancel: String
    let manualEntryTitle: String
    let manualEntryHint: String
    let pasteAPIKey: String
    let save: String

    // Einstellungen
    let refreshEvery: String
    let minutesSuffix: String
    let showBalanceInMenuBar: String
    let showCentsInMenuBar: String
    let burnRate: String
    let burnWindow: String
    let launchAtLogin: String
    let warningThreshold: String
    let language: String
    let removeToken: String

    // Fehler
    let invalidResponse: String
    let unauthorized: String
    let serverError: String  // mit %d
    let unexpectedPayload: String
    let signInDenied: String
    let signInExpired: String
    let keychainError: String  // mit %d

    // Widget
    let widgetDescription: String
    let widgetSetupHint: String
    let widgetNoData: String
    let widgetTopUp: String

    // Benachrichtigungen
    let notifLowTitle: String
    let notifCriticalTitle: String
    let notifBody: String  // mit %@ (Restguthaben)

    func statusLabel(_ status: CreditStatus) -> String {
        switch status {
        case .healthy: statusHealthy
        case .low: statusLow
        case .critical: statusCritical
        }
    }

    static let en = L10nTable(
        refreshNow: "Refresh now",
        statusHealthy: "Balance OK",
        statusLow: "Balance low",
        statusCritical: "Balance almost depleted",
        updatedAt: "Updated:",
        loadingBalance: "Loading balance …",
        addCredits: "Add credits",
        settings: "Settings",
        quit: "Quit",
        connectTitle: "Connect Kilo Code",
        connectBody: "Sign in with your Kilo account to fetch your balance.",
        signInWithBrowser: "Sign in with browser",
        waitingForBrowser: "Waiting for approval in browser …",
        codeLabel: "Code",
        cancel: "Cancel",
        manualEntryTitle: "Enter API key manually",
        manualEntryHint: "You'll find the key at the bottom of app.kilo.ai/profile.",
        pasteAPIKey: "Paste API key",
        save: "Save",
        refreshEvery: "Refresh every",
        minutesSuffix: "min",
        showBalanceInMenuBar: "Show balance in menu bar",
        showCentsInMenuBar: "Show cents in menu bar",
        burnRate: "Burn rate",
        burnWindow: "Burn-rate window",
        launchAtLogin: "Launch at login",
        warningThreshold: "Warning threshold",
        language: "Language",
        removeToken: "Remove token",
        invalidResponse: "Invalid server response",
        unauthorized: "Token invalid or expired",
        serverError: "Server error (HTTP %d)",
        unexpectedPayload: "Unexpected response format",
        signInDenied: "Sign-in was denied",
        signInExpired: "Sign-in expired, please try again",
        keychainError: "Keychain error (%d)",
        widgetDescription: "Shows your remaining Kilo Code credits.",
        widgetSetupHint: "Open Kilocode Credits and sign in",
        widgetNoData: "No data yet",
        widgetTopUp: "Top up",
        notifLowTitle: "Kilo credits low",
        notifCriticalTitle: "Kilo credits almost depleted",
        notifBody: "Only %@ left. Time to top up."
    )

    static let de = L10nTable(
        refreshNow: "Jetzt aktualisieren",
        statusHealthy: "Guthaben OK",
        statusLow: "Guthaben niedrig",
        statusCritical: "Guthaben fast aufgebraucht",
        updatedAt: "Stand:",
        loadingBalance: "Lade Guthaben …",
        addCredits: "Credits aufladen",
        settings: "Einstellungen",
        quit: "Beenden",
        connectTitle: "Kilo Code verbinden",
        connectBody: "Melde dich mit deinem Kilo-Account an, um dein Guthaben abzurufen.",
        signInWithBrowser: "Mit Browser anmelden",
        waitingForBrowser: "Warte auf Freigabe im Browser …",
        codeLabel: "Code",
        cancel: "Abbrechen",
        manualEntryTitle: "API-Key manuell eingeben",
        manualEntryHint: "Den Key findest du unten auf app.kilo.ai/profile.",
        pasteAPIKey: "API-Key einfügen",
        save: "Speichern",
        refreshEvery: "Aktualisieren alle",
        minutesSuffix: "Min.",
        showBalanceInMenuBar: "Guthaben in Menüleiste anzeigen",
        showCentsInMenuBar: "Cents in Menüleiste anzeigen",
        burnRate: "Verbrauch",
        burnWindow: "Verbrauchs-Zeitfenster",
        launchAtLogin: "Bei Anmeldung starten",
        warningThreshold: "Warnschwelle",
        language: "Sprache",
        removeToken: "Token entfernen",
        invalidResponse: "Ungültige Antwort vom Server",
        unauthorized: "Token ungültig oder abgelaufen",
        serverError: "Serverfehler (HTTP %d)",
        unexpectedPayload: "Antwortformat nicht erkannt",
        signInDenied: "Anmeldung wurde abgelehnt",
        signInExpired: "Anmeldung abgelaufen, bitte erneut versuchen",
        keychainError: "Keychain-Fehler (%d)",
        widgetDescription: "Zeigt dein verbleibendes Kilo-Code-Guthaben.",
        widgetSetupHint: "Kilocode Credits öffnen und anmelden",
        widgetNoData: "Noch keine Daten",
        widgetTopUp: "Aufladen",
        notifLowTitle: "Kilo-Guthaben niedrig",
        notifCriticalTitle: "Kilo-Guthaben fast aufgebraucht",
        notifBody: "Nur noch %@ übrig. Zeit zum Aufladen."
    )

    static let es = L10nTable(
        refreshNow: "Actualizar ahora",
        statusHealthy: "Saldo OK",
        statusLow: "Saldo bajo",
        statusCritical: "Saldo casi agotado",
        updatedAt: "Actualizado:",
        loadingBalance: "Cargando saldo …",
        addCredits: "Añadir créditos",
        settings: "Ajustes",
        quit: "Salir",
        connectTitle: "Conectar Kilo Code",
        connectBody: "Inicia sesión con tu cuenta de Kilo para consultar tu saldo.",
        signInWithBrowser: "Iniciar sesión con el navegador",
        waitingForBrowser: "Esperando aprobación en el navegador …",
        codeLabel: "Código",
        cancel: "Cancelar",
        manualEntryTitle: "Introducir clave API manualmente",
        manualEntryHint: "Encontrarás la clave al final de app.kilo.ai/profile.",
        pasteAPIKey: "Pegar clave API",
        save: "Guardar",
        refreshEvery: "Actualizar cada",
        minutesSuffix: "min",
        showBalanceInMenuBar: "Mostrar saldo en la barra de menús",
        showCentsInMenuBar: "Mostrar céntimos en la barra de menús",
        burnRate: "Consumo",
        burnWindow: "Ventana de consumo",
        launchAtLogin: "Abrir al iniciar sesión",
        warningThreshold: "Umbral de aviso",
        language: "Idioma",
        removeToken: "Eliminar token",
        invalidResponse: "Respuesta del servidor no válida",
        unauthorized: "Token no válido o caducado",
        serverError: "Error del servidor (HTTP %d)",
        unexpectedPayload: "Formato de respuesta no reconocido",
        signInDenied: "Inicio de sesión denegado",
        signInExpired: "Inicio de sesión caducado, inténtalo de nuevo",
        keychainError: "Error del llavero (%d)",
        widgetDescription: "Muestra tu saldo restante de Kilo Code.",
        widgetSetupHint: "Abre Kilocode Credits e inicia sesión",
        widgetNoData: "Aún no hay datos",
        widgetTopUp: "Recargar",
        notifLowTitle: "Saldo de Kilo bajo",
        notifCriticalTitle: "Saldo de Kilo casi agotado",
        notifBody: "Solo quedan %@. Es hora de recargar."
    )

    static let zh = L10nTable(
        refreshNow: "立即刷新",
        statusHealthy: "余额充足",
        statusLow: "余额偏低",
        statusCritical: "余额即将用尽",
        updatedAt: "更新于：",
        loadingBalance: "正在加载余额…",
        addCredits: "充值",
        settings: "设置",
        quit: "退出",
        connectTitle: "连接 Kilo Code",
        connectBody: "使用你的 Kilo 账户登录以获取余额。",
        signInWithBrowser: "通过浏览器登录",
        waitingForBrowser: "等待浏览器中确认…",
        codeLabel: "验证码",
        cancel: "取消",
        manualEntryTitle: "手动输入 API 密钥",
        manualEntryHint: "密钥位于 app.kilo.ai/profile 页面底部。",
        pasteAPIKey: "粘贴 API 密钥",
        save: "保存",
        refreshEvery: "刷新间隔",
        minutesSuffix: "分钟",
        showBalanceInMenuBar: "在菜单栏显示余额",
        showCentsInMenuBar: "菜单栏显示小数",
        burnRate: "消耗速度",
        burnWindow: "消耗统计时段",
        launchAtLogin: "登录时启动",
        warningThreshold: "警告阈值",
        language: "语言",
        removeToken: "移除令牌",
        invalidResponse: "服务器响应无效",
        unauthorized: "令牌无效或已过期",
        serverError: "服务器错误（HTTP %d）",
        unexpectedPayload: "无法识别响应格式",
        signInDenied: "登录被拒绝",
        signInExpired: "登录已过期，请重试",
        keychainError: "钥匙串错误（%d）",
        widgetDescription: "显示你剩余的 Kilo Code 余额。",
        widgetSetupHint: "打开 Kilocode Credits 并登录",
        widgetNoData: "暂无数据",
        widgetTopUp: "充值",
        notifLowTitle: "Kilo 余额偏低",
        notifCriticalTitle: "Kilo 余额即将用尽",
        notifBody: "仅剩 %@，该充值了。"
    )

    static let ja = L10nTable(
        refreshNow: "今すぐ更新",
        statusHealthy: "残高OK",
        statusLow: "残高わずか",
        statusCritical: "残高がほぼゼロです",
        updatedAt: "更新:",
        loadingBalance: "残高を読み込み中…",
        addCredits: "クレジットを追加",
        settings: "設定",
        quit: "終了",
        connectTitle: "Kilo Code に接続",
        connectBody: "Kilo アカウントでサインインして残高を取得します。",
        signInWithBrowser: "ブラウザでサインイン",
        waitingForBrowser: "ブラウザでの承認を待っています…",
        codeLabel: "コード",
        cancel: "キャンセル",
        manualEntryTitle: "APIキーを手動で入力",
        manualEntryHint: "キーは app.kilo.ai/profile の最下部にあります。",
        pasteAPIKey: "APIキーを貼り付け",
        save: "保存",
        refreshEvery: "更新間隔",
        minutesSuffix: "分",
        showBalanceInMenuBar: "メニューバーに残高を表示",
        showCentsInMenuBar: "メニューバーにセントを表示",
        burnRate: "消費ペース",
        burnWindow: "消費の集計期間",
        launchAtLogin: "ログイン時に起動",
        warningThreshold: "警告しきい値",
        language: "言語",
        removeToken: "トークンを削除",
        invalidResponse: "サーバーの応答が無効です",
        unauthorized: "トークンが無効か期限切れです",
        serverError: "サーバーエラー（HTTP %d）",
        unexpectedPayload: "応答形式を認識できません",
        signInDenied: "サインインが拒否されました",
        signInExpired: "サインインの有効期限が切れました。もう一度お試しください",
        keychainError: "キーチェーンエラー（%d）",
        widgetDescription: "Kilo Code の残高を表示します。",
        widgetSetupHint: "Kilocode Credits を開いてサインイン",
        widgetNoData: "データがありません",
        widgetTopUp: "チャージ",
        notifLowTitle: "Kilo 残高わずか",
        notifCriticalTitle: "Kilo 残高がほぼゼロです",
        notifBody: "残り %@ です。チャージしましょう。"
    )

    static let ru = L10nTable(
        refreshNow: "Обновить сейчас",
        statusHealthy: "Баланс в порядке",
        statusLow: "Баланс на исходе",
        statusCritical: "Баланс почти исчерпан",
        updatedAt: "Обновлено:",
        loadingBalance: "Загрузка баланса…",
        addCredits: "Пополнить кредиты",
        settings: "Настройки",
        quit: "Выйти",
        connectTitle: "Подключить Kilo Code",
        connectBody: "Войдите в учётную запись Kilo, чтобы получить баланс.",
        signInWithBrowser: "Войти через браузер",
        waitingForBrowser: "Ожидание подтверждения в браузере…",
        codeLabel: "Код",
        cancel: "Отмена",
        manualEntryTitle: "Ввести API-ключ вручную",
        manualEntryHint: "Ключ находится внизу страницы app.kilo.ai/profile.",
        pasteAPIKey: "Вставьте API-ключ",
        save: "Сохранить",
        refreshEvery: "Обновлять каждые",
        minutesSuffix: "мин",
        showBalanceInMenuBar: "Показывать баланс в строке меню",
        showCentsInMenuBar: "Показывать центы в строке меню",
        burnRate: "Расход",
        burnWindow: "Окно расчёта расхода",
        launchAtLogin: "Запускать при входе",
        warningThreshold: "Порог предупреждения",
        language: "Язык",
        removeToken: "Удалить токен",
        invalidResponse: "Недопустимый ответ сервера",
        unauthorized: "Токен недействителен или истёк",
        serverError: "Ошибка сервера (HTTP %d)",
        unexpectedPayload: "Неизвестный формат ответа",
        signInDenied: "Вход отклонён",
        signInExpired: "Время входа истекло, попробуйте ещё раз",
        keychainError: "Ошибка связки ключей (%d)",
        widgetDescription: "Показывает остаток кредитов Kilo Code.",
        widgetSetupHint: "Откройте Kilocode Credits и войдите",
        widgetNoData: "Пока нет данных",
        widgetTopUp: "Пополнить",
        notifLowTitle: "Баланс Kilo на исходе",
        notifCriticalTitle: "Баланс Kilo почти исчерпан",
        notifBody: "Осталось всего %@. Пора пополнить."
    )
}
