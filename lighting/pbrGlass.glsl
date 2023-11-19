#include "../color/tonemap.glsl"

#include "material.glsl"
#include "light/new.glsl"
#include "ior.glsl"
#include "envMap.glsl"
#include "specular.glsl"
#include "fresnelReflection.glsl"

#include "ior/2eta.glsl"
#include "ior/2f0.glsl"

#include "reflection.glsl"
#include "common/specularAO.glsl"
#include "common/envBRDFApprox.glsl"

/*
contributors: Patricio Gonzalez Vivo
description: simple glass shading model
use: 
    - <vec4> glass(<Material> material) 
    
options:
    - SPECULAR_FNC: specularGaussian, specularBeckmann, specularCookTorrance (default), specularPhongRoughness, specularBlinnPhongRoughnes (default on mobile)
    - SCENE_BACK_SURFACE: 
    - LIGHT_POSITION: in GlslViewer is u_light
    - LIGHT_DIRECTION: 
    - LIGHT_COLOR in GlslViewer is u_lightColor
    - CAMERA_POSITION: in GlslViewer is u_camera
examples:
    - /shaders/lighting_raymarching_glass.frag
*/

#ifndef IBL_LUMINANCE
#define IBL_LUMINANCE   1.0
#endif

#ifndef FNC_PBRGLASS
#define FNC_PBRGLASS

vec4 pbrGlass(const Material _mat) {
    
    // Cached
    Material M  = _mat;
    M.V         = normalize(CAMERA_POSITION - M.position);  // View
    M.R         = reflection(M.V, M.normal, M.roughness);   // Reflection
    M.NoV       = dot(M.normal, M.V);                       // Normal . View

#if defined(SCENE_BACK_SURFACE)
    vec3    No      = normalize(M.normal - M.normal_back); // Normal out is the difference between the front and back normals
#else
    vec3    No      = M.normal;                            // Normal out
#endif

    vec3    f0      = ior2f0(M.ior);
    vec3    eta     = ior2eta(M.ior);
    

    // Global Ilumination ( mage Based Lighting )
    // ------------------------
    vec3 E = envBRDFApprox(M.albedo.rgb, M);

    vec3 Fr = vec3(0.0, 0.0, 0.0);
    Fr  += envMap(M) * E;
    #if !defined(PLATFORM_RPI)
    #if defined(SHADING_MODEL_IRIDESCENCE)
    Fr  += fresnelIridescentReflection(M.R, M.f0, M.NoV, M.thickness, IOR_AIR, M.ior.r, IOR_AIR, M.roughness);
    #else
    Fr  += fresnelReflection(M) * (1.0-M.roughness);
    #endif
    #endif

    vec4 color  = vec4(0.0, 0.0, 0.0, 1.0);
    #if defined(PBRGLASS_CHROMATIC_LOOP)
    const int LOOP = 10;
    for ( int i = 0; i < PBRGLASS_CHROMATIC_LOOP; i ++ ) {

        float slide = float(i + 1) / float(PBRGLASS_CHROMATIC_LOOP);
        vec3 RaG    = refract(-M.V, No, eta.g);
        vec3 ref    = envMap( mix(-M.V, RaG, slide), M.roughness);
        #if !defined(TARGET_MOBILE) && !defined(PLATFORM_RPI)
        vec3 RaR    = refract(-M.V, No, eta.r);
        vec3 RaB    = refract(-M.V, No, eta.b);
        ref.r       = envMap( mix(-M.V, RaR, slide), M.roughness).r;
        ref.b       = envMap( mix(-M.V, RaB, slide), M.roughness).b;
        #endif

        color.rgb += ref;
    }
    color.rgb /= float(PBRGLASS_CHROMATIC_LOOP);
    #else

    vec3    RaG     = refract(-M.V, No, eta.g);
    color.rgb   = envMap(RaG, M.roughness);
    #if !defined(TARGET_MOBILE) && !defined(PLATFORM_RPI)
    vec3    RaR     = refract(-M.V, No, eta.r);
    vec3    RaB     = refract(-M.V, No, eta.b);
    color.r     = envMap(RaR, M.roughness).r;
    color.b     = envMap(RaB, M.roughness).b;
    #endif

    #endif

    // color.rgb   *= exp( -M.thickness * 2000.0);
    color.rgb   += Fr * IBL_LUMINANCE;

    // TODO: 
    //  - Add support for multiple lights
    // 
    {
        #if defined(LIGHT_DIRECTION)
        LightDirectional L = LightDirectionalNew();
        #elif defined(LIGHT_POSITION)
        LightPoint L = LightPointNew();
        #endif

        #if defined(LIGHT_DIRECTION) || defined(LIGHT_POSITION)
        // lightResolve(diffuseColor, specularColor, M, L, lightDiffuse, lightSpecular);
        vec3 spec = vec3( specular(L.direction, M.normal, M.V, M.roughness) );

        color.rgb += L.color * spec;

        #endif
    }

    return color;
}



#endif
