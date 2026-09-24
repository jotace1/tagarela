import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?
    private var isRecording = false
    private var warning: String?
    private var warningDismissal: Task<Void, Never>?

    private static let idleIcon = menuBarIcon()
        ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Tagarela")
    private static let warningIcon = symbol("exclamationmark.triangle", description: t("Aviso", "Warning"))
    private static let idleToolTip = "Tagarela - Ditado e Transcrição"
    /// Quanto tempo um aviso fica na barra antes de voltar ao ícone normal.
    private static let warningDuration: Duration = .seconds(4)

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupStatusItem()
        observeState()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        render()
    }

    private func observeState() {
        let center = NotificationCenter.default
        center.addObserver(forName: .tagarelaRecordingChanged, object: nil, queue: .main) { [weak self] note in
            let isRecording = note.object as? Bool ?? false
            MainActor.assumeIsolated { self?.setRecording(isRecording) }
        }
        center.addObserver(forName: .tagarelaWarning, object: nil, queue: .main) { [weak self] note in
            let message = note.object as? String ?? ""
            MainActor.assumeIsolated { self?.showWarning(message) }
        }
    }

    private func setRecording(_ recording: Bool) {
        isRecording = recording
        if recording { clearWarning() }
        render()
    }

    private func showWarning(_ message: String) {
        warning = message
        render()
        warningDismissal?.cancel()
        warningDismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.warningDuration)
            guard !Task.isCancelled else { return }
            self?.clearWarning()
            self?.render()
        }
    }

    private func clearWarning() {
        warningDismissal?.cancel()
        warningDismissal = nil
        warning = nil
    }

    /// Gravando não troca o ícone: o indicador de microfone do próprio macOS já
    /// aparece na barra. Um aviso recente mostra o triângulo com a mensagem no
    /// tooltip; fora isso, o ícone do app.
    private func render() {
        guard let button = statusItem?.button else { return }
        button.image = warning == nil ? Self.idleIcon : Self.warningIcon
        if isRecording {
            button.toolTip = t("Tagarela - Gravando", "Tagarela - Recording")
        } else if let warning {
            button.toolTip = warning
        } else {
            button.toolTip = Self.idleToolTip
        }
    }

    private static func symbol(_ name: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        image?.isTemplate = true
        return image
    }

    /// Versão monocromática do ícone do app (boca com ondas sonoras), embutida
    /// como SVG. O original fica em docs/design/menubar.svg.
    private static func menuBarIcon() -> NSImage? {
        let svg = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 6.4 21.8 11.2"><g fill="none" stroke="#000" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12C2.4 9.9 4.2 8.6 5.6 8.7C6.4 8.7 7 9.1 7.5 9.6C8 9.1 8.6 8.7 9.4 8.7C10.8 8.6 12.6 9.9 14 12C13 15 10.5 16.6 7.5 16.6C4.5 16.6 2 15 1 12Z"/><path d="M16.5 9.5Q17.7 12 16.5 14.5"/><path d="M19.5 7.5Q21.8 12 19.5 16.5"/></g><path fill="#000" d="M3.4 12.1C5 11.4 6.3 11.2 7.5 11.35C8.7 11.2 10 11.4 11.6 12.1C10.8 13.8 9.3 14.6 7.5 14.6C5.7 14.6 4.2 13.8 3.4 12.1Z"/></svg>"##
        guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
        // A boca é larga e baixa: o SVG é recortado no desenho e ocupa a altura
        // toda da barra, em vez de um quadrado com o desenho no meio.
        image.size = NSSize(width: 27, height: 14)
        image.isTemplate = true
        image.accessibilityDescription = "Tagarela"
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // Cabeçalho
        let titleItem = NSMenuItem(title: "Tagarela", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Abrir Janela Principal
        let openItem = NSMenuItem(
            title: t("Abrir Tagarela", "Open Tagarela"),
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        // Alternar Ditado
        let dictateItem = NSMenuItem(
            title: t("Iniciar / Parar Ditado", "Start / Stop Dictation"),
            action: #selector(toggleDictation),
            keyEquivalent: "d"
        )
        dictateItem.target = self
        menu.addItem(dictateItem)

        // Ajustes
        let settingsItem = NSMenuItem(
            title: t("Ajustes...", "Settings..."),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle para ocultar sempre da Dock
        let isAlwaysHidden = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        let dockItem = NSMenuItem(
            title: t("Ocultar da Dock sempre", "Always hide from Dock"),
            action: #selector(toggleAlwaysHideFromDock),
            keyEquivalent: ""
        )
        dockItem.state = isAlwaysHidden ? .on : .off
        dockItem.target = self
        menu.addItem(dockItem)

        menu.addItem(NSMenuItem.separator())

        // Encerrar definitivamente
        let quitItem = NSMenuItem(
            title: t("Encerrar Tagarela definitivamente", "Quit Tagarela completely"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openMainWindow() {
        appDelegate?.showMainWindow()
    }

    @objc private func toggleDictation() {
        NotificationCenter.default.post(name: .tagarelaToggleDictation, object: nil)
    }

    @objc private func openSettings() {
        appDelegate?.showMainWindow()
        NotificationCenter.default.post(name: .tagarelaNavigate, object: NavSection.settings)
    }

    @objc private func toggleAlwaysHideFromDock() {
        let current = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: "alwaysHideFromDock")
        appDelegate?.updateActivationPolicy()
    }

    @objc private func quitApp() {
        appDelegate?.terminateCompletely()
    }
}
