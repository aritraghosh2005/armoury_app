import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const bucket = 'component-images';
const maxBytes = 5 * 1024 * 1024;
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-armoury-device-id',
  'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

function response(body: BodyInit | null, status: number, extra = {}) {
  return new Response(body, {
    status,
    headers: { ...corsHeaders, ...extra },
  });
}

function objectPath(request: Request): string | null {
  const value = new URL(request.url).searchParams.get('path') ?? '';
  if (!/^[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\.(jpg|png|webp)$/i.test(value)) {
    return null;
  }
  return value;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return response(null, 204);
  if (request.method !== 'GET' && request.method !== 'PUT') {
    return response('method_not_allowed', 405, { Allow: 'GET, PUT, OPTIONS' });
  }

  const authorization = request.headers.get('Authorization');
  const publishableKey = request.headers.get('apikey');
  const deviceId = request.headers.get('x-armoury-device-id');
  const path = objectPath(request);
  if (!authorization || !publishableKey || !deviceId || !path) {
    return response('invalid_request', 400);
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const token = authorization.replace(/^Bearer\s+/i, '');
  const { data: userResult, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userResult.user) return response('sign_in_required', 401);

  const { error: deviceError } = await userClient.rpc('armoury_authorize_media', {
    p_device_id: deviceId,
    p_write: request.method === 'PUT',
  });
  if (deviceError) return response('media_access_denied', 403);

  const storage = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  }).storage.from(bucket);

  if (request.method === 'PUT') {
    const contentType = request.headers.get('Content-Type')?.split(';')[0] ?? '';
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(contentType)) {
      return response('unsupported_media_type', 415);
    }
    const bytes = await request.arrayBuffer();
    if (bytes.byteLength === 0 || bytes.byteLength > maxBytes) {
      return response('invalid_media_size', 413);
    }
    const { error } = await storage.upload(path, bytes, {
      contentType,
      upsert: true,
    });
    if (error) return response('media_upload_failed', 502);
    return response(JSON.stringify({ uploaded: true }), 200, {
      'Content-Type': 'application/json',
    });
  }

  const { data, error } = await storage.download(path);
  if (error || !data) return response('media_not_found', 404);
  return response(data, 200, {
    'Content-Type': data.type || 'application/octet-stream',
    'Cache-Control': 'private, max-age=300',
  });
});
