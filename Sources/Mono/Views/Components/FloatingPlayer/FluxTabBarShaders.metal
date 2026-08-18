//
//  FluxTabBarShaders.metal
//  Mono
//
//  Domain-warped FBM material adapted from KTBOY/shuke-lab-flux (MIT),
//  commit cb2708aaa07d87b62b465eddadcbc8a9bb81f0b0.
//  Ported from WebGL GLSL to SwiftUI Metal. The player material preserves the
//  original five-octave domain-warped FBM structure.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float fluxHash(float2 point) {
    point = fract(point * float2(123.34, 456.21) + 1.0);
    point += dot(point, point + 45.32);
    return fract(point.x * point.y);
}

static float fluxNoise(float2 point) {
    float2 cell = floor(point);
    float2 fraction = fract(point);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);

    float a = fluxHash(cell);
    float b = fluxHash(cell + float2(1.0, 0.0));
    float c = fluxHash(cell + float2(0.0, 1.0));
    float d = fluxHash(cell + float2(1.0, 1.0));
    return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

static float fluxFBM(float2 point) {
    float value = 0.0;
    float amplitude = 0.55;
    const float2x2 rotation = float2x2(0.8, 0.6, -0.6, 0.8);

    for (uint octave = 0; octave < 5; ++octave) {
        value += amplitude * fluxNoise(point);
        point = rotation * point * 2.0 + 3.7;
        amplitude *= 0.5;
    }
    return value;
}

// 以下三段保持 shuke-lab-flux 原版五阶 FBM 的参数与噪声结构。
// 全屏背景只替换输入颜料色，不再改写流体形态。
static float fluxBackgroundHash(float2 point, float seed) {
    point = fract(point * float2(123.34, 456.21) + seed);
    point += dot(point, point + 45.32);
    return fract(point.x * point.y);
}

static float fluxBackgroundNoise(float2 point, float seed) {
    float2 cell = floor(point);
    float2 fraction = fract(point);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);

    float a = fluxBackgroundHash(cell, seed);
    float b = fluxBackgroundHash(cell + float2(1.0, 0.0), seed);
    float c = fluxBackgroundHash(cell + float2(0.0, 1.0), seed);
    float d = fluxBackgroundHash(cell + float2(1.0, 1.0), seed);
    return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

static float fluxBackgroundFBM(float2 point, float seed) {
    float value = 0.0;
    float amplitude = 0.55;
    const float2x2 rotation = float2x2(0.8, 0.6, -0.6, 0.8);

    for (uint octave = 0; octave < 5; ++octave) {
        value += amplitude * fluxBackgroundNoise(point, seed);
        point = rotation * point * 2.0 + 3.7;
        amplitude *= 0.5;
    }
    return value;
}

[[ stitchable ]] half4 asideMusicFluidBackgroundMaterial(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float darkMode,
    half4 firstColor,
    half4 secondColor,
    half4 thirdColor
) {
    float2 safeSize = max(size, float2(1.0));
    float minimumDimension = max(min(safeSize.x, safeSize.y), 1.0);
    float2 uv = position / safeSize;
    // 全屏背景以画面中心建立等比例噪声域，避免竖屏时把整个流体域
    // 压缩并推到右下角。固定偏移只用于选取稳定的初始云团切片。
    float2 point = (position - safeSize * 0.5) / minimumDimension * 1.55
        + float2(1.18, 0.72);
    float flowTime = time * 0.22;
    const float seed = 1.0;

    float2 warpA = float2(
        fluxBackgroundFBM(point + flowTime * float2(0.6, 0.2), seed),
        fluxBackgroundFBM(point + flowTime * float2(-0.4, 0.5) + 5.2, seed)
    );
    float2 warpB = float2(
        fluxBackgroundFBM(point + 2.2 * warpA + flowTime * float2(0.3, -0.4) + 1.7, seed),
        fluxBackgroundFBM(point + 2.2 * warpA + flowTime * float2(-0.2, 0.3) + 8.3, seed)
    );
    float field = fluxBackgroundFBM(point + 2.4 * warpB, seed);

    float3 color = mix(
        float3(firstColor.rgb),
        float3(secondColor.rgb),
        smoothstep(0.15, 0.62, field)
    );
    color = mix(
        color,
        float3(thirdColor.rgb),
        smoothstep(0.60, 0.95, clamp(warpA.x * 1.3, 0.0, 1.0))
    );
    color += 0.15 * warpB.y * float3(secondColor.rgb);

    float darkness = clamp(darkMode, 0.0, 1.0);
    // WebGL 的 gl_FragCoord 原点在左下；SwiftUI layerEffect 坐标原点在左上，
    // 因此翻转 y 才能保持原版顶部白雾的位置。
    float edgeMist = smoothstep(0.50, 1.05, 1.0 - uv.y) * 0.55;
    float density = smoothstep(0.32, 0.85, field + 0.22 * warpB.x);
    // 胶囊原版的 colorZone 会固定把左侧留白、颜色压向右侧；全屏背景
    // 不需要文字留白，改由云团密度决定覆盖范围，让流体遍布整个画面。
    float openPockets = smoothstep(0.18, 0.78, warpA.y + field * 0.24);
    float mask = clamp(0.22 + density * 0.58 + openPockets * 0.20, 0.0, 0.96);

    float3 base = mix(float3(0.985), float3(0.025, 0.030, 0.038), darkness);
    color = mix(color, color * 0.48, darkness);
    float3 result = mix(base, color, mask);
    result = mix(result, base, edgeMist * 0.18 * (1.0 - mask * 0.35));

    return half4(half3(clamp(result, 0.0, 1.0)), currentColor.a);
}

[[ stitchable ]] half4 fluxTabMaterial(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float progress,
    float stir,
    float motionSeed,
    float darkMode,
    half4 firstColor,
    half4 secondColor,
    half4 thirdColor
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float aspect = safeSize.x / safeSize.y;
    float stirAmount = clamp(stir, 0.0, 1.0);
    float seed = clamp(motionSeed, 0.0, 1.0);
    float spatialScale = 1.38 + fract(seed * 7.31) * 0.58;
    float2 seedOffset = float2(
        fract(seed * 13.17) * 7.4,
        fract(seed * 29.43 + 0.37) * 5.8
    );
    float2 point = uv * float2(aspect, 1.0) * spatialScale
        + seedOffset
        + float2(stirAmount * 0.34, -stirAmount * 0.18);
    // 时间始终连续；搅动只改变域偏移和饱和度，避免交互时相位跳变。
    float flowSpeed = 0.14 + fract(seed * 11.79 + 0.21) * 0.17;
    float flowTime = time * flowSpeed + seed * 9.7;

    float2 driftA = normalize(float2(
        0.34 + fract(seed * 5.13) * 0.46,
        -0.18 + fract(seed * 17.21) * 0.62
    ));
    float2 driftB = normalize(float2(
        -0.54 + fract(seed * 23.71) * 0.40,
        0.22 + fract(seed * 31.19) * 0.48
    ));
    float warpStrength = 1.86 + fract(seed * 19.37) * 0.72;

    float2 warpA = float2(
        fluxFBM(point + flowTime * driftA),
        fluxFBM(point + flowTime * driftB + 5.2 + seed * 2.8)
    );
    float2 warpB = float2(
        fluxFBM(point + warpStrength * warpA + flowTime * driftB.yx + 1.7),
        fluxFBM(point + warpStrength * warpA - flowTime * driftA.yx + 8.3 + seed)
    );
    float field = fluxFBM(point + (2.05 + seed * 0.72) * warpB);

    float3 color = mix(
        float3(firstColor.rgb),
        float3(secondColor.rgb),
        smoothstep(0.15, 0.62, field)
    );
    color = mix(
        color,
        float3(thirdColor.rgb),
        smoothstep(0.60, 0.95, clamp(warpA.x * 1.3, 0.0, 1.0))
    );
    color += 0.15 * warpB.y * float3(secondColor.rgb);
    color = mix(color, color * color * 1.35 + color * 0.12, stirAmount * 0.55);

    float cloudDensity = smoothstep(0.32, 0.85, field + 0.22 * warpB.x);
    // 原项目为卡片左侧文字保留了灰白区域；播放器没有这项排版需求。
    // 颜色覆盖率只跟云团密度变化，确保进度从 0% 开始就是封面颜料，
    // 而不是先经过一段灰色再慢慢出现颜色。
    float cloudVariation = smoothstep(0.18, 0.82, warpA.y + field * 0.22);
    float cloudMask = clamp(
        0.52 + cloudDensity * 0.32 + cloudVariation * 0.16,
        0.0,
        0.98
    );
    float darkness = clamp(darkMode, 0.0, 1.0);
    float3 base = mix(float3(0.985), float3(0.025, 0.030, 0.038), darkness);
    color = mix(color, color * 0.48, darkness);
    float3 result = mix(base, color, cloudMask);

    float topMist = smoothstep(0.58, 1.05, 1.0 - uv.y) * 0.16;
    result = mix(result, base, topMist * (1.0 - cloudMask * 0.72));

    // 播放进度只决定侵染区域的中心位置，不直接生成竖直裁切线。
    // 两层域扭曲与当前云团密度共同推动边缘，使不同高度出现凸起、
    // 回缩和细小分叉；歌曲结束时再强制完整铺满。
    float safeProgress = clamp(progress, 0.0, 1.0);
    float interiorGate = smoothstep(0.015, 0.12, safeProgress)
        * (1.0 - smoothstep(0.88, 0.985, safeProgress));

    float breathFrequency = 8.6 + fract(seed * 37.1) * 5.2;
    float verticalBreath = sin(
        uv.y * breathFrequency + warpA.x * (3.4 + seed * 2.1) + flowTime * (0.54 + seed * 0.42)
    ) * (0.019 + seed * 0.014);
    float cloudDisplacement =
        (warpB.y - 0.5) * 0.22
        + (warpA.y - 0.5) * 0.105
        + (field - 0.5) * 0.075
        + verticalBreath;
    float fluidFront = safeProgress + cloudDisplacement * interiorGate;
    float signedFrontDistance = fluidFront - uv.x;
    float frontFeather = mix(0.012, 0.044, interiorGate);
    float playedMask = smoothstep(
        -frontFeather,
        frontFeather * 0.58,
        signedFrontDistance
    );

    // 云团密集处形成向前探出的柔软小分叉，稀疏处自然退后。
    float nearFront = 1.0 - smoothstep(0.035, 0.20, abs(uv.x - safeProgress));
    float plume = smoothstep(0.66, 0.92, field + warpA.x * 0.12)
        * nearFront
        * interiorGate;
    playedMask = max(
        playedMask,
        plume * smoothstep(-0.11, 0.025, signedFrontDistance + 0.075)
    );
    playedMask *= smoothstep(0.0, 0.016, safeProgress);
    if (safeProgress >= 0.995) {
        playedMask = 1.0;
    }

    float frontGlow = 1.0 - smoothstep(0.0, 0.060, abs(signedFrontDistance));
    result += mix(float3(0.055), float3(0.022), darkness) * frontGlow * playedMask;

    // SwiftUI 合成链使用预乘透明度。未播放区域同时清零 RGB 和 alpha，
    // 避免颜色残留被后续毛玻璃/合成步骤重新显现成“整条已有流体”。
    half finalAlpha = currentColor.a * half(playedMask);
    half3 premultipliedResult = half3(clamp(result, 0.0, 1.0)) * finalAlpha;
    return half4(premultipliedResult, finalAlpha);
}
