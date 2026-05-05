import { handleRequest } from './handler.js'
import type { Env } from './types.js'

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      return await handleRequest(request, env, ctx)
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      // eslint-disable-next-line no-console
      console.log(
        JSON.stringify({
          level: 'error',
          ts: new Date().toISOString(),
          msg: 'unhandled_exception',
          err: message,
        }),
      )
      return new Response('internal error', { status: 500 })
    }
  },
} satisfies ExportedHandler<Env>
