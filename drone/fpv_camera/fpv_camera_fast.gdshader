shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float hfov;

uniform sampler2D Texture0 : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D Texture1 : hint_default_black, filter_linear, repeat_disable;


vec3 latlon_to_ray(vec2 latlon) {
	float lat = latlon.x;
	float lon = latlon.y;
	return vec3(sin(lon) * cos(lat), sin(lat), -cos(lon) * cos(lat));
}

vec3 fisheye_inverse(vec2 p) {
	float r = sqrt(p.x * p.x + p.y * p.y);
	
	if (r > PI) {
		return vec3(0.0, 0.0, 0.0);
	}
	else {
		float theta = r;
		float s = sin(theta);
		return vec3(p.x / r * s, p.y / r * s, -cos(theta));
	}
}
vec2 fisheye_forward(vec2 latlon) {
	vec3 ray = latlon_to_ray(latlon);
	float theta = acos(-ray.z);
	float r = theta;
	float c = r / length(ray.xy);
	return vec2(ray.x * c, ray.y * c);
}
vec3 fisheye_ray(vec2 p) {
	float scale = fisheye_forward(vec2(0.0, radians(hfov) / 2.0)).x;
	return fisheye_inverse(p * scale);
}

vec3 srgb_to_linear(vec3 color) {
	return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 get_transformation(vec2 uv) {
	return(fisheye_ray(uv));
}


void vertex() {
	// Same fix the full shader got in the Godot 4.6 port: with reverse-Z a depth of 0 is the
	// far plane and the quad was clipped, leaving only the sky (or black) on screen.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	bool debug = false;
	
	vec3 color_front = vec3(1.0, 1.0, 1.0);
	vec3 color_back = vec3(1.0, 1.0, 0.0);
	vec3 color_left = vec3(1.0, 0.0, 0.0);
	vec3 color_right = vec3(1.0, 0.2, 0.0);
	vec3 color_bottom = vec3(0.0, 1.0, 0.0);
	vec3 color_top = vec3(0.0, 0.0, 1.0);
	float alpha = 0.5;
	
	float view_ratio = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 uv = FRAGCOORD.xy / min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
	vec3 pos = vec3(0.0, 0.0, 0.0);
	if (view_ratio > 1.0) {
		pos = get_transformation(vec2(uv.x - 0.5 * view_ratio, uv.y - 0.5) * 1.0);
	} else {
		pos = get_transformation(vec2(uv.x - 0.5, uv.y - 0.5 / view_ratio) * 1.0);
	}
	if (pos.z >= 0.0) {
		// Behind the camera (only reachable with very wide FOVs): black, like the full mode
		ALBEDO = vec3(0.0, 0.0, 0.0);
	} else {
		float dist = 0.5 / tan(radians(160.0) / 2.0);
		float size = 2.0 * dist * tan(PI / 4.0);
		
		float u = pos.x / pos.z * dist;
		float v = pos.y / pos.z * dist;
		
		if (abs(u) < size / 2.0 && abs(v) < size / 2.0) {
			// The front camera renders 100 degrees (like the full mode) to avoid seams
			float fov_fix = tan(radians(90.0 / 2.0)) / tan(radians(100.0 / 2.0));
			uv = vec2(fov_fix * 0.5 * (vec2(pos.x / abs(pos.z), pos.y / abs(pos.z))) + 0.5);
			ALBEDO = srgb_to_linear(texture(Texture0, uv).rgb);
		} else {
			// The screen corners go beyond the 160 degrees of this camera: stretch its edge
			// instead of wrapping around, which showed a repeated (mirror-like) image
			uv = clamp(-vec2(u, v) + 0.5, vec2(0.0), vec2(1.0));
			ALBEDO = srgb_to_linear(texture(Texture1, uv).rgb);
		}
	}
	if (debug) {
		ALBEDO = vec3(uv.x, uv.y, 0.0); // debug UV display
	}
}