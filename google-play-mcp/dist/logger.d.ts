/**
 * 📝 Structured Logger for MCP Servers
 * Provides timestamped, leveled logging to stderr (MCP protocol requirement)
 */
export type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
export declare class Logger {
    private serviceName;
    private minLevel;
    private levelPriority;
    constructor(serviceName: string, minLevel?: LogLevel);
    private formatMessage;
    private shouldLog;
    debug(message: string, context?: Record<string, unknown>): void;
    info(message: string, context?: Record<string, unknown>): void;
    warn(message: string, context?: Record<string, unknown>): void;
    error(message: string, context?: Record<string, unknown>): void;
    /**
     * Log an error with stack trace
     */
    exception(message: string, error: Error, context?: Record<string, unknown>): void;
}
