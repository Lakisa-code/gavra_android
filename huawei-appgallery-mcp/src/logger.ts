/**
 * 📝 Structured Logger for MCP Servers
 * Provides timestamped, leveled logging to stderr (MCP protocol requirement)
 */

export type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';

export class Logger {
    private serviceName: string;
    private minLevel: LogLevel;

    private levelPriority: Record<LogLevel, number> = {
        DEBUG: 0,
        INFO: 1,
        WARN: 2,
        ERROR: 3,
    };

    constructor(serviceName: string, minLevel: LogLevel = 'INFO') {
        this.serviceName = serviceName;
        this.minLevel = minLevel;
    }

    private formatMessage(level: LogLevel, message: string, context?: Record<string, unknown>): string {
        const timestamp = new Date().toISOString();
        const contextStr = context ? ` ${JSON.stringify(context)}` : '';
        return `[${timestamp}] [${level}] [${this.serviceName}] ${message}${contextStr}`;
    }

    private shouldLog(level: LogLevel): boolean {
        return this.levelPriority[level] >= this.levelPriority[this.minLevel];
    }

    debug(message: string, context?: Record<string, unknown>): void {
        if (this.shouldLog('DEBUG')) {
            console.error(this.formatMessage('DEBUG', message, context));
        }
    }

    info(message: string, context?: Record<string, unknown>): void {
        if (this.shouldLog('INFO')) {
            console.error(this.formatMessage('INFO', message, context));
        }
    }

    warn(message: string, context?: Record<string, unknown>): void {
        if (this.shouldLog('WARN')) {
            console.error(this.formatMessage('WARN', message, context));
        }
    }

    error(message: string, context?: Record<string, unknown>): void {
        if (this.shouldLog('ERROR')) {
            console.error(this.formatMessage('ERROR', message, context));
        }
    }

    /**
     * Log an error with stack trace
     */
    exception(message: string, error: Error, context?: Record<string, unknown>): void {
        const errorContext = {
            ...context,
            errorName: error.name,
            errorMessage: error.message,
            stack: error.stack?.split('\n').slice(0, 5).join('\n'),
        };
        this.error(message, errorContext);
    }
}
