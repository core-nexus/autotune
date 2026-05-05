export type LogLevel = 'debug' | 'info' | 'warn' | 'error'

const ORDER: Record<LogLevel, number> = { debug: 0, info: 1, warn: 2, error: 3 }

export function createLogger(min: string | undefined) {
  const floor = ORDER[(min as LogLevel) ?? 'info'] ?? ORDER.info
  return (level: LogLevel, fields: Record<string, unknown>) => {
    if (ORDER[level] < floor) return
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ level, ts: new Date().toISOString(), ...fields }))
  }
}

export type Logger = ReturnType<typeof createLogger>
