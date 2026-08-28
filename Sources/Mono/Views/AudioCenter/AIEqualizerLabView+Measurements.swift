import SwiftUI
import FFmpegSwiftSDK

extension AIEqualizerLabView {
    func measurementSection(_ features: AIEqualizerAudioFeatures) -> AnyView {
        erasedSection(
            title: String(localized: "ai_lab_measured_parameters"),
            content: AnyView(
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    SpectrumMeasurementView(
                        values: features.bandEnergyDB,
                        frequencies: features.bandFrequenciesHz,
                        mode: features.graphicEQMode,
                        accent: accent
                    )
                    .frame(height: 156)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(
                            String(localized: "ai_lab_bpm"),
                            bpmText(features.estimatedBPM, confidence: features.tempoConfidence)
                        )
                        measurementCell(
                            String(localized: "ai_lab_key"),
                            keyText(features.estimatedKey, confidence: features.keyConfidence)
                        )
                        measurementCell(
                            String(localized: "ai_lab_integrated_loudness"),
                            String(format: "%.1f LUFS", features.integratedLUFS)
                        )
                        measurementCell(
                            String(localized: "ai_lab_dr_value"),
                            String(format: "DR %.1f", features.dynamicRangeDR)
                        )
                    }
                }
                .padding(14)

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .music,
                    content: { AnyView(
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                            spacing: 8
                        ) {
                            measurementCell(String(localized: "ai_lab_main_melody"), pitchText(features.dominantPitchHz))
                            measurementCell(
                                String(localized: "ai_lab_melody_range"),
                                String(format: String(localized: "ai_lab_semitones_format"), features.melodyRangeSemitones)
                            )
                            measurementCell(String(localized: "ai_lab_melodic_activity"), "\(Int(features.melodicActivity * 100))%")
                            measurementCell(
                                String(localized: "ai_lab_transient_density"),
                                String(format: String(localized: "ai_lab_density_format"), features.transientDensity)
                            )
                            measurementCell(String(localized: "ai_lab_tempo_stability"), "\(Int(features.tempoStability * 100))%")
                        }

                        if !features.melodyContourHz.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "ai_lab_melody_contour"))
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.52))

                                MelodyContourView(frequencies: features.melodyContourHz, accent: accent)
                                    .frame(height: 58)
                                    .accessibilityHidden(true)
                            }
                        }

                        if !features.genreHints.isEmpty {
                            analysisTagRow(
                                title: String(localized: "ai_lab_genre_hints"),
                                values: features.genreHints,
                                localizationPrefix: "ai_genre_"
                            )
                        }
                        if !features.instrumentHints.isEmpty {
                            analysisTagRow(
                                title: String(localized: "ai_lab_instrument_hints"),
                                values: features.instrumentHints,
                                localizationPrefix: "ai_instrument_"
                            )
                        }
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .loudness,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_loudness"), String(format: "%.1f dBFS", features.rmsDBFS))
                        measurementCell(String(localized: "ai_lab_dynamic_range"), String(format: "%.1f dB", features.dynamicSpreadDB))
                        measurementCell(String(localized: "ai_lab_loudness_range"), String(format: "%.1f LU", features.loudnessRangeLU))
                        measurementCell(String(localized: "ai_lab_true_peak"), String(format: "%.1f dBTP", features.estimatedTruePeakDBTP))
                        measurementCell(String(localized: "ai_lab_crest_factor"), String(format: "%.1f dB", features.crestFactorDB))
                        measurementCell(String(localized: "ai_lab_clipping"), String(format: "%.3f%%", features.clippingRatio * 100))
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .spatial,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_phase_correlation"), String(format: "%.2f", features.phaseCorrelation))
                        measurementCell(String(localized: "ai_lab_mono_compatibility"), "\(Int(features.monoCompatibility * 100))%")
                        measurementCell(String(localized: "ai_lab_measured_stereo_width"), String(format: "%.2fx", features.measuredStereoWidth))
                        measurementCell(String(localized: "ai_lab_spectral_centroid"), frequencyText(features.spectralCentroidHz))
                        measurementCell(String(localized: "ai_lab_spectral_bandwidth"), frequencyText(features.spectralBandwidthHz))
                        measurementCell(String(localized: "ai_lab_spectral_rolloff"), frequencyText(features.spectralRolloffHz))
                        measurementCell(String(localized: "ai_lab_spectral_flatness"), "\(Int(features.spectralFlatness * 100))%")
                        measurementCell(String(localized: "ai_lab_low_energy"), "\(Int(features.lowEnergyRatio * 100))%")
                        measurementCell(String(localized: "ai_lab_mid_energy"), "\(Int(features.midEnergyRatio * 100))%")
                        measurementCell(String(localized: "ai_lab_high_energy"), "\(Int(features.highEnergyRatio * 100))%")
                    }
                    ) }
                )

                divider.padding(.horizontal, 14)

                erasedMeasurementGroup(
                    .sample,
                    content: { AnyView(
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        measurementCell(String(localized: "ai_lab_sample_rate"), String(format: "%.1f kHz", features.sampleRate / 1_000))
                        measurementCell(String(localized: "ai_lab_sample_duration"), String(format: "%.1f s", features.sampleDuration))
                        measurementCell(String(localized: "ai_lab_sample_frames"), "\(features.frameCount)")
                    }
                    ) }
                )
            }
            .background(cardBackground)
            )
        )
    }

    func erasedMeasurementGroup(
        _ group: AIEqualizerMeasurementGroup,
        content: @escaping () -> AnyView
    ) -> AnyView {
        let isExpanded = expandedMeasurementGroups.contains(group)

        return AnyView(VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    if isExpanded {
                        expandedMeasurementGroups.remove(group)
                    } else {
                        expandedMeasurementGroups.insert(group)
                    }
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 12) {
                    Text(group.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Spacer()

                    MonoIcon(
                        icon: .chevronDown,
                        size: 11,
                        color: isExpanded ? accent : .white.opacity(0.38),
                        lineWidth: 1.8
                    )
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                isExpanded
                    ? String(localized: "ai_lab_measurement_expanded")
                    : String(localized: "ai_lab_measurement_collapsed")
            )

            if isExpanded {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: isExpanded
        )
        )
    }

    func measurementCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 5)
    }

    func analysisTagRow(
        title: String,
        values: [String],
        localizationPrefix: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Text(NSLocalizedString(localizationPrefix + value, comment: ""))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(Capsule().fill(accent.opacity(0.15)))
                    }
                }
            }
        }
    }

    func bpmText(_ bpm: Float, confidence: Float) -> String {
        guard bpm > 0 else { return "—" }
        let prefix = confidence < 0.5 ? "≈ " : ""
        return prefix + String(format: "%.0f BPM", bpm)
    }

    func keyText(_ key: String, confidence: Float) -> String {
        guard !key.isEmpty else { return "—" }
        let localizedKey = key
            .replacingOccurrences(of: " major", with: String(localized: "ai_key_major_suffix"))
            .replacingOccurrences(of: " minor", with: String(localized: "ai_key_minor_suffix"))
        return (confidence < 0.35 ? "≈ " : "") + localizedKey
    }

    func pitchText(_ frequency: Float) -> String {
        guard frequency.isFinite, frequency > 0 else { return "—" }
        let midi = Int((69 + 12 * log2f(frequency / 440)).rounded())
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let pitchClass = (midi % 12 + 12) % 12
        let octave = midi / 12 - 1
        return "≈ \(names[pitchClass])\(octave) · \(frequencyText(frequency))"
    }

}
