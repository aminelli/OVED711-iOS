// Azioni Interattive

import UserNotifications

// MARK: - Registrazione categorie

func registerNotificationCategories() {
    // Azione di risposta testuale
    let replyAction = UNTextInputNotificationAction(
        identifier: "REPLY_ACTION",
        title: "Rispondi",
        options: [.foreground],
        textInputButtonTitle: "Invia",
        textInputPlaceholder: "Scrivi un messaggio..."
    )

    // Azione di dismissione
    let dismissAction = UNNotificationAction(
        identifier: "DISMISS_ACTION",
        title: "Ignora",
        options: [.destructive]
    )

    // Categoria che raggruppa le azioni
    let messageCategory = UNNotificationCategory(
        identifier: "MESSAGE_CATEGORY",
        actions: [replyAction, dismissAction],
        intentIdentifiers: [],
        options: .customDismissAction
    )

    UNUserNotificationCenter.current().setNotificationCategories([messageCategory])
}