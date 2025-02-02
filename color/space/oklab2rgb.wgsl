const fwd_oklab_A : mat3x3<f32>  = mat3x3<f32>( vec3f(1.0, 1.0, 1.0), 
                                                vec3f(0.3963377774, -0.1055613458, -0.0894841775), 
                                                vec3f(0.2158037573, -0.0638541728, -1.2914855480) );

const fwd_oklab_B : mat3x3<f32>  = mat3x3<f32>( vec3f(4.0767245293, -1.2681437731, -0.0041119885), 
                                                vec3f(-3.3072168827, 2.3098, 0.2307590544), 
                                                vec3f(-0.3411344290,  1.7066093323231, -0.7034768625689) );

fn oklab2rgb(oklab: vec3f) -> vec3f {
    let lms = fwd_oklab_A * oklab;
    return fwd_oklab_B * (lms * lms * lms);
}