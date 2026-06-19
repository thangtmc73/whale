import Foundation

/// Models how switching provider/model is handled. Same-provider model switches resume the
/// existing CLI session natively (cheap, no new Session row). Cross-provider switches can't
/// resume natively — each CLI owns its own session format — so they always create a new
/// Session, optionally carrying forward context as that new session's opening draft text.
enum SessionTransition {
    case resumeSameProvider(session: Session, newModel: ModelOption)
    case newSessionDifferentProvider(from: Session, newProvider: AgentProvider, newModel: ModelOption, contextHandoff: String?)

    static func decide(currentSession: Session, newProvider: AgentProvider, newModel: ModelOption, contextHandoff: String?) -> SessionTransition {
        if newProvider == currentSession.provider {
            return .resumeSameProvider(session: currentSession, newModel: newModel)
        }
        return .newSessionDifferentProvider(from: currentSession, newProvider: newProvider, newModel: newModel, contextHandoff: contextHandoff)
    }
}
