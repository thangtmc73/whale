import Foundation

/// Shared contract for wrapping each provider's CLI as a subprocess. `session` is passed in
/// full (not just its cliSessionID) because some providers can't pre-assign a session id the
/// way Claude can with `--session-id` — Cursor only learns its real chat id after calling
/// `create-chat`, so the service needs `session.hasBeenStarted` to know whether that setup step
/// is needed, and a way to report the resolved id back so the caller can persist it.
protocol AgentCLIService {
    var provider: AgentProvider { get }

    func sendTurn(
        prompt: String,
        in projectPath: URL,
        session: Session,
        model: ModelOption,
        permissionMode: PermissionMode,
        onRawLine: @escaping (String) -> Void,
        onResolveCLISessionID: @escaping (String) -> Void
    ) -> AsyncThrowingStream<Step, Error>

    func cancelCurrentTurn()
}
