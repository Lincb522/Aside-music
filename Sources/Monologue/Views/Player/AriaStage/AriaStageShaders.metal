//
//  AriaStageShaders.metal
//  Monologue
//
//  镜头语言：没有常驻的果冻漂移。只有音乐能量到达后，宽幅折射带
//  才沿画面连续经过；色散集中在镜头边缘，暗角以慢速呼吸。
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

inline float ariaGaussian(float value, float width) {
    float normalized = value / max(width, 0.001);
    return exp(-normalized * normalized);
}

/// 节拍连绵折射 + 镜头聚焦。
/// 无音频能量时位移为 0；所有位移合计控制在 12pt 采样预算内。
[[ stitchable ]] float2 ariaOpticalFlow(
    float2 position,
    float2 size,
    float time,
    float bass,
    float energy,
    float punch,
    float tension
) {
    float2 safeSize = max(size, float2(1.0));
    float2 center = safeSize * 0.5;
    float minHalf = max(min(center.x, center.y), 1.0);
    float2 centered = position - center;
    float2 p = centered / minHalf;
    float radius = length(p);
    float2 radial = radius > 0.001 ? p / radius : float2(0.0);

    const float2 travelAxis = float2(0.861934, 0.507020);
    const float2 bandNormal = float2(-travelAxis.y, travelAxis.x);
    float lane = dot(p, bandNormal);

    // 两条宽幅折射带依次穿过舞台。它们只有在音乐能量出现时才显形，
    // 因此静止画面不会产生持续摇晃或果冻感。
    float cycle = fract(time * (0.048 + clamp(energy, 0.0, 1.0) * 0.018));
    float centerA = mix(-1.75, 1.75, cycle);
    float centerB = centerA > 0.15 ? centerA - 1.90 : centerA + 1.90;
    float bandA = ariaGaussian(lane - centerA, 0.24);
    float bandB = ariaGaussian(lane - centerB, 0.38) * 0.52;
    float energyGate = smoothstep(0.045, 0.38, clamp(energy, 0.0, 1.0));
    float refractionStrength = (bandA + bandB)
        * energyGate
        * (1.15 + bass * 2.15 + punch * 2.05);
    float edgeLimiter = 1.0 - smoothstep(1.28, 1.72, radius);
    float2 refraction = travelAxis * refractionStrength * edgeLimiter;

    // 低频只做很轻的中心聚焦；副歌张力扩大镜头尺度但不扭曲局部。
    float focusWindow = smoothstep(0.08, 0.46, radius)
        * (1.0 - smoothstep(0.72, 1.36, radius));
    float focusStrength = bass * 1.35 + tension * 2.30 + punch * 0.70;
    float2 focus = -radial * focusWindow * focusStrength;

    return position + refraction + focus;
}

/// 镜头边缘色散 + 节拍微光 + 呼吸暗角。
/// 色散不参与中心主体，最大偏移小于 Swift 侧声明的 4pt。
[[ stitchable ]] half4 ariaLensFinish(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float punch,
    float energy,
    float treble
) {
    float2 safeSize = max(size, float2(1.0));
    float2 center = safeSize * 0.5;
    float minHalf = max(min(center.x, center.y), 1.0);
    float2 centered = position - center;
    float radius = length(centered) / minHalf;
    float2 radial = radius > 0.001 ? normalize(centered) : float2(0.0);

    float edge = smoothstep(0.54, 1.34, radius);
    float chroma = edge * (0.45 + treble * 0.92 + punch * 1.18);
    chroma = min(chroma, 3.35);

    half4 base = layer.sample(position);
    half red = layer.sample(position + radial * chroma).r;
    half blue = layer.sample(position - radial * chroma).b;
    half4 color = half4(red, base.g, blue, base.a);

    // 折射带经过时同时带来很轻的曝光抬升，让光学运动能被看见，
    // 但保持中性色，不生成明显的 RGB 光污染。
    float2 p = centered / minHalf;
    const float2 bandNormal = float2(-0.507020, 0.861934);
    float lane = dot(p, bandNormal);
    float cycle = fract(time * (0.048 + clamp(energy, 0.0, 1.0) * 0.018));
    float bandCenter = mix(-1.75, 1.75, cycle);
    float opticalBand = ariaGaussian(lane - bandCenter, 0.30)
        * smoothstep(0.05, 0.40, energy);
    float exposureLift = opticalBand * (0.018 + energy * 0.035 + punch * 0.025);
    color.rgb += half3(exposureLift, exposureLift * 0.98, exposureLift * 0.94);

    // 节拍光只抬高中心亮度，不叠加有色闪烁。
    float centerMask = 1.0 - smoothstep(0.06, 0.86, radius);
    float bloom = punch * centerMask * 0.055;
    color.rgb += half3(bloom, bloom * 0.965, bloom * 0.92);

    // 慢速呼吸暗角：安静段收拢，高能段打开。
    float breathing = 0.5 + 0.5 * sin(time * 0.58);
    float vignette = (0.055 + (1.0 - clamp(energy, 0.0, 1.0)) * 0.085)
        * mix(0.86, 1.12, breathing)
        * smoothstep(0.48, 1.38, radius)
        * (1.0 - clamp(punch, 0.0, 1.0) * 0.24);
    color.rgb *= half(1.0 - vignette);

    return half4(min(color.rgb, half3(1.0)), color.a);
}

/// 歌词棱镜边缘 + 分幕色光。中心字形直接取原图，保证可读性；
/// 光晕只从字形邻域扩散，不会给歌词额外铺设底板。
[[ stitchable ]] half4 ariaLyricOptics(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float energy,
    float ambience,
    float punch,
    half4 tint
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float2 center = safeSize * 0.5;
    float2 fromCenter = position - center;
    float distanceFromCenter = length(fromCenter);
    float2 radial = distanceFromCenter > 0.001
        ? fromCenter / distanceFromCenter
        : float2(0.707107, 0.707107);

    half4 base = layer.sample(position);

    // 节拍时产生短距离棱镜边缘；中心原始绿色通道保持不动，字形不会发虚。
    float separation = 0.42 + clamp(energy, 0.0, 1.0) * 0.62
        + clamp(punch, 0.0, 1.0) * 1.55;
    float2 prismAxis = normalize(radial + float2(0.32, -0.18));
    half red = layer.sample(position + prismAxis * separation).r;
    half blue = layer.sample(position - prismAxis * separation).b;
    half4 color = half4(red, base.g, blue, base.a);

    // 八向邻域只用于生成字外光晕，半径由 ambience 控制。
    float haloRadius = 1.4 + clamp(ambience, 0.0, 1.0) * 4.2
        + clamp(punch, 0.0, 1.0) * 1.1;
    const float diagonal = 0.707107;
    const float2 directions[8] = {
        float2(1.0, 0.0), float2(-1.0, 0.0),
        float2(0.0, 1.0), float2(0.0, -1.0),
        float2(diagonal, diagonal), float2(-diagonal, diagonal),
        float2(diagonal, -diagonal), float2(-diagonal, -diagonal)
    };
    half neighbourAlpha = half(0.0);
    for (uint index = 0; index < 8; ++index) {
        neighbourAlpha = max(
            neighbourAlpha,
            layer.sample(position + directions[index] * haloRadius).a
        );
    }
    half halo = max(half(0.0), neighbourAlpha - base.a * half(0.72));
    half haloStrength = half(0.22 + ambience * 0.32 + energy * 0.13);
    color.rgb += tint.rgb * halo * haloStrength;
    color.a = max(color.a, halo * half(0.46));

    // 一条非常宽的光带缓慢经过字面，只改变已有字形内部的亮度。
    float sweepPosition = fract(time * 0.085) * 1.65 - 0.32;
    float sweepDistance = (uv.x + uv.y * 0.17) - sweepPosition;
    float sweep = exp(-pow(sweepDistance / 0.12, 2.0));
    float sweepStrength = sweep * (0.035 + energy * 0.075) * float(base.a);
    color.rgb += tint.rgb * half(sweepStrength);

    return half4(min(color.rgb, half3(1.0)), color.a);
}
