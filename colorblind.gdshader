shader_type canvas_item;

uniform int colorblind_mode : hint_range(0, 4) = 0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// Color blindness simulation matrices
// Based on research by Machado et al. (2009)

vec3 protanopia(vec3 color) {
    mat3 m = mat3(
        vec3(0.567, 0.433, 0.0),
        vec3(0.558, 0.442, 0.0),
        vec3(0.0, 0.242, 0.758)
    );
    return m * color;
}

vec3 deuteranopia(vec3 color) {
    mat3 m = mat3(
        vec3(0.625, 0.375, 0.0),
        vec3(0.7, 0.3, 0.0),
        vec3(0.0, 0.3, 0.7)
    );
    return m * color;
}

vec3 tritanopia(vec3 color) {
    mat3 m = mat3(
        vec3(0.95, 0.05, 0.0),
        vec3(0.0, 0.433, 0.567),
        vec3(0.0, 0.475, 0.525)
    );
    return m * color;
}

vec3 grayscale(vec3 color) {
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    return vec3(gray);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 original = tex_color.rgb;
    vec3 result = original;
    
    if (colorblind_mode == 1) {
        result = protanopia(original);
    } else if (colorblind_mode == 2) {
        result = deuteranopia(original);
    } else if (colorblind_mode == 3) {
        result = tritanopia(original);
    } else if (colorblind_mode == 4) {
        result = grayscale(original);
    }
    
    // Mix between original and filtered based on intensity
    result = mix(original, result, intensity);
    
    COLOR = vec4(result, tex_color.a);
}
