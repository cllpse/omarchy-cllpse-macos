// The unfocused cursor as a block at 10% strength.
//
// Ghostty draws the cursor as a hollow outline on an unfocused surface, and no
// config key changes that. This post-process fills the cursor's cell with the
// cursor colour at FILL over whatever is in it, so the character under it shows
// through. Focused frames, and frames with the cursor hidden, pass through.
//
// Linked into ~/.config/ghostty/shaders/ by ghostty.sh and loaded by the
// custom-shader line in ghostty.conf, which says why it is a shader.

const float FILL = 0.1;

// How far in from the cell's edge Ghostty's hollow outline can reach, in px.
// Its thickness is the font's underline, 1 px at text size 18.
const float OUTLINE = 3.0;

// The screen arrives linear: Ghostty's OpenGL textures are sRGB-format, so
// sampling decodes them, and the output is encoded again on write. The colour
// uniforms are the config's sRGB values divided by 255, so they are decoded to
// match. Used as they come, the background put back under the outline is too
// light (#1E1E1E reads as #606060) and the frame stays, faintly.
vec3 toLinear(vec3 c) {
    return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92,
               vec3(lessThanEqual(c, vec3(0.04045))));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 c = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = c;
    if (iFocus != 0 || iCursorVisible.x <= 0.0) return;

    // xy is the cell's -X, +Y corner (fragCoord runs y-up), zw its size. p is
    // this pixel's centre measured from the cell's top left.
    vec4 r = iCurrentCursor;
    vec2 p = vec2(fragCoord.x - r.x, r.y - fragCoord.y);
    if (p.x < 0.0 || p.y < 0.0 || p.x >= r.z || p.y >= r.w) return;

    // The outline is already drawn, in the cursor colour, and under a
    // translucent fill it would show as a frame. An edge pixel in that colour
    // goes back to the background before the fill.
    vec3 cursor = toLinear(iCursorColor);
    vec3 under = c.rgb;
    float edge = min(min(p.x, r.z - p.x), min(p.y, r.w - p.y));
    if (edge < OUTLINE && distance(under, cursor) < 0.1) under = toLinear(iBackgroundColor);

    fragColor = vec4(mix(under, cursor, FILL), c.a);
}
