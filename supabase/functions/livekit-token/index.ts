import { createClient } from 'npm:@supabase/supabase-js@2'
import { AccessToken, TrackSource } from 'npm:livekit-server-sdk@2.19.2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: Record<string, unknown>, status = 200) =>  
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const authorization = request.headers.get('Authorization')
  const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]
  if (!bearer) return json({ error: 'Sign in to join a voice room.' }, 401)

  let spaceId: string
  try {
    const body = await request.json()
    spaceId = typeof body.spaceId === 'string' ? body.spaceId : ''
  } catch {
    return json({ error: 'Invalid request body.' }, 400)
  }
  if (!spaceId || spaceId.length > 64) return json({ error: 'A valid spaceId is required.' }, 400)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const publishableKeys = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  let publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY')
  if (!publishableKey && publishableKeys) {
    try { publishableKey = JSON.parse(publishableKeys).default } catch { /* handled below */ }
  }
  const livekitUrl = Deno.env.get('LIVEKIT_URL')
  const apiKey = Deno.env.get('LIVEKIT_API_KEY')
  const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
  if (!supabaseUrl || !publishableKey || !livekitUrl || !apiKey || !apiSecret) {
    return json({ error: 'Voice rooms are not configured on the server yet.' }, 503)
  }

  const supabase = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: `Bearer ${bearer}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: { user }, error: authError } = await supabase.auth.getUser(bearer)
  if (authError || !user) return json({ error: 'Your session expired. Sign in again.' }, 401)

  // The user-scoped query is subject to RLS. A member can only mint a token for a space
  // whose membership is visible to their own authenticated session.
  const { data: membership, error: memberError } = await supabase
    .from('study_space_members')
    .select('display_name')
    .eq('space_id', spaceId)
    .eq('user_id', user.id)
    .maybeSingle()
  if (memberError || !membership) return json({ error: 'You are not a member of this private space.' }, 403)

  const roomName = `studybridge_${spaceId}`
  const token = new AccessToken(apiKey, apiSecret, {
    identity: user.id,
    name: membership.display_name,
    ttl: '10m',
  })
  token.addGrant({
    roomJoin: true,
    room: roomName,
    canSubscribe: true,
    canPublishSources: [TrackSource.MICROPHONE],
    canPublishData: false,
  })
  return json({ serverUrl: livekitUrl, roomName, token: await token.toJwt() })
})
