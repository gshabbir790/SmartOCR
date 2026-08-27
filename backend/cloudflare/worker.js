export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/api/conversation') {
      return handleConversation(request, env);
    }
    if (request.method === 'POST' && url.pathname === '/api/ocr') {
      return handleOcr(request, env);
    }
    return new Response('Not found', {status:404});
  }
};

async function handleConversation(request, env) {
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

// Manual, on-demand OCR fallback for images Tesseract reads poorly
// (decorative/calligraphic Nastaliq, stylized fonts, low contrast).
// The Flutter app only calls this when the user taps "Try AI OCR" —
// never automatically.
//
// NOTE: this assumes an OpenAI-compatible chat-completions endpoint with
// vision support (works with OpenAI, Azure OpenAI, and many OpenAI-compatible
// gateways/routers). If you use a different provider (e.g. Google Gemini's
// generateContent, or Anthropic's Messages API), adjust the `upstreamBody`
// shape and the response-parsing line below to match that provider's format.
//
// Set OCR_PROVIDER_URL / OCR_PROVIDER_KEY in the Worker env if the vision
// model differs from the text-conversation provider; otherwise it falls
// back to AI_PROVIDER_URL / AI_PROVIDER_KEY.
async function handleOcr(request, env) {
  const ct = request.headers.get('content-type') || '';
  if (!ct.includes('application/json')) return new Response('Invalid content type', {status:415});
  const body = await request.json();
  const imageBase64 = String(body.imageBase64 || '');
  const mimeType = String(body.mimeType || 'image/jpeg');
  if (!imageBase64) return new Response('Missing image', {status:400});
  // Reject anything absurdly large before it reaches the provider.
  if (imageBase64.length > 15_000_000) return new Response('Image too large', {status:413});

  const providerUrl = env.OCR_PROVIDER_URL || env.AI_PROVIDER_URL;
  const providerKey = env.OCR_PROVIDER_KEY || env.AI_PROVIDER_KEY;

  const upstreamBody = {
    model: env.OCR_PROVIDER_MODEL || 'gpt-4o-mini',
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: 'Extract every word of visible text from this image exactly as written, preserving line breaks and the original script (Urdu/Arabic/English/Hindi as applicable). Return ONLY the extracted text, with no commentary, translation, or extra formatting.'
          },
          {
            type: 'image_url',
            image_url: { url: `data:${mimeType};base64,${imageBase64}` }
          }
        ]
      }
    ],
    max_tokens: 2000
  };

  const upstream = await fetch(providerUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'authorization': `Bearer ${providerKey}`
    },
    body: JSON.stringify(upstreamBody)
  });

  if (!upstream.ok) return new Response('AI OCR provider error', {status:502});
  const data = await upstream.json();
  const text = data.choices?.[0]?.message?.content ?? data.answer ?? data.output ?? '';
  return Response.json({text});
}
