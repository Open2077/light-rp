-- Staff voice announcements (server/modules/announce.lua): /lightrp.broadcast carries a
-- staff member's voice to the whole server or to everyone within a radius of them.
LightRpAnnounce = {
    -- /lightrp.broadcast <radius>: metres, clamped to this range.
    minRadius = 10,
    maxRadius = 3000,
    -- How often the audience follows the speaker and the players' moves.
    refreshMs = 500,
    -- Players already within the speaker's proximity voice hear them in 3D: they are
    -- left out of the channel (no double voice). Hysteresis in metres at that edge.
    proximityHysteresis = 3,
    -- The voice channel's audience cap (the platform's maximumChannelAudience is 128,
    -- the speaker is one of them).
    maxAudience = 127,
    -- The public-address sound: a little brighter and larger than a voice in the street.
    effect = {
        gain = 1.25,
        highPassHz = 110.0,
        lowPassHz = 10500.0,
        distortion = 0.03,
        radioNoise = 0.0,
        spatialBlend = 0.0,
        reverbWet = 0.22,
        reverbRoomSize = 0.9,
        reverbDecay = 2.2,
        reverbDamping = 0.45,
        reverbPreDelayMs = 22.0,
    },
}
