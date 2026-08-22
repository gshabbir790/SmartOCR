export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/api/conversation') return new Response('Not found', {status:404});
    const ct = request.headers.get('content-type') || '';
    if (!ct.includes('application/json')) return new Response('Invalid content type', {status:415});
    const body = await request.json();
    const text = String(body.text || '').slice(0, 100000);
    const question = String(body.question || '').slice(0, 4000);
    if (!text || !question) return new Response('Missing fields', {status:400});
    // Provider secret stays in Worker env, never in Flutter.
    const upstream = await fetch(env.AI_PROVIDER_URL, {method:'POST',headers:{'content-type':'application/json','authorization':`Bearer ${env.AI_PROVIDER_KEY}`},body:JSON.stringify({text,question})});
    if (!upstream.ok) return new Response('AI provider error', {status:502});
    const data = await upstream.json();
    return Response.json({answer:data.answer ?? data.output ?? ''});
  }
};
