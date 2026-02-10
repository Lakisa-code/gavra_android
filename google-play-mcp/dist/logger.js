/**
 * 📝 Structured Logger for MCP Servers
 * Provides timestamped, leveled logging to stderr (MCP protocol requirement)
 */
export class Logger {
    serviceName;
    minLevel;
    levelPriority = {
        DEBUG: 0,
        INFO: 1,
        WARN: 2,
        ERROR: 3,
    };
    constructor(serviceName, minLevel = 'INFO') {
        this.serviceName = serviceName;
        this.minLevel = minLevel;
    }
    formatMessage(level, message, context) {
        const timestamp = new Date().toISOString();
        const contextStr = context ? ` ${JSON.stringify(context)}` : '';
        return `[${timestamp}] [${level}] [${this.serviceName}] ${message}${contextStr}`;
    }
    shouldLog(level) {
        return this.levelPriority[level] >= this.levelPriority[this.minLevel];
    }
    debug(message, context) {
        if (this.shouldLog('DEBUG')) {
            console.error(this.formatMessage('DEBUG', message, context));
        }
    }
    info(message, context) {
        if (this.shouldLog('INFO')) {
            console.error(this.formatMessage('INFO', message, context));
        }
    }
    warn(message, context) {
        if (this.shouldLog('WARN')) {
            console.error(this.formatMessage('WARN', message, context));
        }
    }
    error(message, context) {
        if (this.shouldLog('ERROR')) {
            console.error(this.formatMessage('ERROR', message, context));
        }
    }
    /**
     * Log an error with stack trace
     */
    exception(message, error, context) {
        const errorContext = {
            ...context,
            errorName: error.name,
            errorMessage: error.message,
            stack: error.stack?.split('\n').slice(0, 5).join('\n'),
        };
        this.error(message, errorContext);
    }
}
