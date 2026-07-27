//
//  AriaStageShaders.metal
//  Mono
//
//  镜头语言：没有常驻漂移和横穿画面的扫光。低频只推动中心景深，
//  重拍产生原地扩散的镜头压力；色散集中在镜头边缘。
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// 音频驱动的径向镜头压力 + 镜头聚焦。
/// 无音频能量时位移为 0；所有位移合计控制在 12pt 采样预算内。
[[ stitchable ]] float2 ariaOpticalFlow(
    float2 position,
    float2 size,
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

    // 重拍只在原地压出柔和的同心响应，不再有任何横穿画面的带状运动。
    float energyGate = smoothstep(0.05, 0.42, clamp(energy, 0.0, 1.0));
    float ringWindow = smoothstep(0.08, 0.34, radius)
        * (1.0 - smoothstep(0.76, 1.42, radius));
    float ringWave = sin(radius * 13.5 + bass * 1.8) * 0.5 + 0.5;
    float refractionStrength = ringWindow
        * ringWave
        * energyGate
        * (punch * 2.35 + bass * 0.42);
    float edgeLimiter = 1.0 - smoothstep(1.28, 1.72, radius);
    float2 refraction = radial * refractionStrength * edgeLimiter;

    // 低频只做很轻的中心聚焦；副歌张力扩大镜头尺度但不扭曲局部。
    float focusWindow = smoothstep(0.08, 0.46, radius)
        * (1.0 - smoothstep(0.72, 1.36, radius));
    float focusStrength = bass * 1.35 + tension * 2.30 + punch * 0.70;
    float2 focus = -radial * focusWindow * focusStrength;

    return position + refraction + focus;
}

/// 镜头边缘色散 + 节拍微光 + 音频暗角。
/// 色散不参与中心主体，最大偏移小于 Swift 侧声明的 4pt。
[[ stitchable ]] half4 ariaLensFinish(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
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
    half4 color = base;
    // 中心区域不发生色散，直接复用原采样；避免大面积重复读取同一像素。
    if (edge > 0.001 && chroma > 0.001) {
        color.r = layer.sample(position + radial * chroma).r;
        color.b = layer.sample(position - radial * chroma).b;
    }

    // 节拍光只抬高中心亮度，不叠加有色闪烁。
    float centerMask = 1.0 - smoothstep(0.06, 0.86, radius);
    float bloom = punch * centerMask * 0.055;
    color.rgb += half3(bloom, bloom * 0.965, bloom * 0.92);

    // 暗角直接跟随音频开合，不再用时间函数持续唤醒一层无意义动画。
    float vignette = (0.055 + (1.0 - clamp(energy, 0.0, 1.0)) * 0.085)
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

    // 四向邻域生成字外光晕。相比八向采样减半纹理读取，轮廓厚度不变。
    float haloRadius = 1.4 + clamp(ambience, 0.0, 1.0) * 4.2
        + clamp(punch, 0.0, 1.0) * 1.1;
    const float2 directions[4] = {
        float2(1.0, 0.0), float2(-1.0, 0.0),
        float2(0.0, 1.0), float2(0.0, -1.0)
    };
    half neighbourAlpha = half(0.0);
    for (uint index = 0; index < 4; ++index) {
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
    float sweep = 1.0 - smoothstep(0.0, 0.12, abs(sweepDistance));
    float sweepStrength = sweep * (0.035 + energy * 0.075) * float(base.a);
    color.rgb += tint.rgb * half(sweepStrength);

    return half4(min(color.rgb, half3(1.0)), color.a);
}
