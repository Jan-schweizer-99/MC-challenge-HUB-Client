// Effekt-Schalter je Stage (Menue "Stage Effects"). Aus = der Effekt wird nicht kompiliert und kostet nichts.
// Die Arena-Schalter gelten fuer alle Arenen gemeinsam.
#define FX_HUB // All hub effects
#define FX_HUB_AURORA // Northern lights above the hub.
#define FX_HUB_HEART // The floating, spinning heart in the middle.
#define FX_HUB_FLOOR // Pixel waves, grid and twinkle on the floor.
#define FX_HUB_PILLARS // Light above the ten pedestals.
#define FX_HUB_SNOW // Slowly sinking bright dots.
#define FX_ARENA // All arena effects
#define FX_ARENA_AURA // Soft glow above the beacon.
#define FX_ARENA_ORBS // Light orbs with trails around the center.
#define FX_ARENA_SHAFT // Light rings and rising sparks in the center.
#define FX_ARENA_COMETS // Flying cubes with glowing edges and trails.
#define FX_ARENA_ARCS // Light paths of the jump pads.
#define FX_ARENA_SKY // Aurora, in the End arena the ender sky.
#define FX_ARENA_ROUND_FLOOR // Smooth round rings instead of blocky ones.
#define FX_ARENA_CIRCLES // Thin light circles and scale on the floor.
#define FX_ARENA_WAVES // Waves running out from the center.
#define FX_ARENA_SPOKES // Light pulses on the floor spokes.
#define FX_ARENA_SPARKLE // Sparkle on the outer ring.
#define FX_ARENA_SPAWNS // Pulsing rings around the spawn blocks.
#define FX_ARENA_EDGES // Glowing block edges on walls and stands.
#define FX_ARENA_DOTS // Dots running along the stands.
#define FX_ARENA_PILLARS // Glow and pulses in the wall pillars.
#define FX_ARENA_TORCHES // Torches and their light in arena colors.
#define FX_ARENA_CRYSTALS // Crystal blocks pulse with light.
#define FX_ARENA_BEAMS // Crystal beams, End arena only.
// Ueberschriften im Menue sind Hauptschalter: aus = alle Effekte des Bereichs aus
#ifndef FX_HUB
#undef FX_HUB_AURORA
#undef FX_HUB_HEART
#undef FX_HUB_FLOOR
#undef FX_HUB_PILLARS
#undef FX_HUB_SNOW
#endif
#ifndef FX_ARENA
#undef FX_ARENA_AURA
#undef FX_ARENA_ORBS
#undef FX_ARENA_SHAFT
#undef FX_ARENA_COMETS
#undef FX_ARENA_ARCS
#undef FX_ARENA_SKY
#undef FX_ARENA_ROUND_FLOOR
#undef FX_ARENA_CIRCLES
#undef FX_ARENA_WAVES
#undef FX_ARENA_SPOKES
#undef FX_ARENA_SPARKLE
#undef FX_ARENA_SPAWNS
#undef FX_ARENA_EDGES
#undef FX_ARENA_DOTS
#undef FX_ARENA_PILLARS
#undef FX_ARENA_TORCHES
#undef FX_ARENA_CRYSTALS
#undef FX_ARENA_BEAMS
#endif
