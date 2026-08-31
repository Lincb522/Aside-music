#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def insert_once(path: Path, marker: str, anchor: str, replacement: str) -> None:
    text = path.read_text()
    if marker in text:
        return
    if anchor not in text:
        raise RuntimeError(f"Audio Vivid patch anchor not found in {path}")
    path.write_text(text.replace(anchor, replacement, 1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ffmpeg_source", type=Path)
    args = parser.parse_args()

    source = args.ffmpeg_source.resolve()
    package = Path(__file__).resolve().parent.parent
    vendor = package / "Vendor" / "AudioVivid"
    decoder_source = vendor / "decoder"
    codec_source = vendor / "ffmpeg" / "av3adec.c"

    required = [
        source / "libavcodec" / "codec_id.h",
        source / "libavcodec" / "codec_desc.c",
        source / "libavcodec" / "allcodecs.c",
        source / "libavcodec" / "Makefile",
        source / "libavformat" / "isom_tags.c",
        source / "libavformat" / "mpegts.c",
        source / "libavformat" / "mpegts.h",
        codec_source,
        decoder_source / "decoder.c",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise RuntimeError("Missing Audio Vivid inputs:\n" + "\n".join(missing))

    target_decoder = source / "libavcodec" / "audio_vivid"
    target_decoder.mkdir(parents=True, exist_ok=True)
    for path in decoder_source.iterdir():
        if path.suffix.lower() in {".c", ".h"}:
            shutil.copy2(path, target_decoder / path.name)
    shutil.copy2(codec_source, source / "libavcodec" / "av3adec.c")

    insert_once(
        source / "libavcodec" / "codec_id.h",
        "AV_CODEC_ID_AV3A",
        "    AV_CODEC_ID_G728,\n\n    /* subtitle codecs */",
        "    AV_CODEC_ID_G728,\n    AV_CODEC_ID_AV3A,\n\n    /* subtitle codecs */",
    )

    insert_once(
        source / "libavcodec" / "codec_desc.c",
        '        .name      = "av3a",',
        "\n    /* subtitle codecs */",
        """
    {
        .id        = AV_CODEC_ID_AV3A,
        .type      = AVMEDIA_TYPE_AUDIO,
        .name      = "av3a",
        .long_name = NULL_IF_CONFIG_SMALL("AVS3-P3 / Audio Vivid"),
        .props     = AV_CODEC_PROP_LOSSY,
    },

    /* subtitle codecs */""",
    )

    insert_once(
        source / "libavcodec" / "allcodecs.c",
        "extern const FFCodec ff_av3a_decoder;",
        "extern const FFCodec ff_avrn_decoder;",
        "extern const FFCodec ff_av3a_decoder;\nextern const FFCodec ff_avrn_decoder;",
    )

    objects = sorted(path.stem for path in decoder_source.glob("*.c"))
    object_lines = " \\\n                                          ".join(
        f"audio_vivid/{name}.o" for name in objects
    )
    makefile_block = (
        "OBJS-$(CONFIG_AV3A_DECODER)            += av3adec.o \\\n                                          "
        + object_lines
        + "\nlibavcodec/audio_vivid/%.o: CPPFLAGS += "
        "-I$(SRC_PATH)/libavcodec/audio_vivid -DAVS3_LIBRARY_ONLY\n"
    )
    makefile_anchor = "OBJS-$(CONFIG_AV1_DECODER)             += av1dec.o av1_parse.o\n"
    insert_once(
        source / "libavcodec" / "Makefile",
        "OBJS-$(CONFIG_AV3A_DECODER)",
        makefile_anchor,
        makefile_anchor + makefile_block,
    )
    insert_once(
        source / "libavcodec" / "Makefile",
        "libavcodec/audio_vivid/%.o: CFLAGS += -Wno-missing-prototypes",
        "libavcodec/audio_vivid/%.o: CPPFLAGS += "
        "-I$(SRC_PATH)/libavcodec/audio_vivid -DAVS3_LIBRARY_ONLY\n",
        "libavcodec/audio_vivid/%.o: CPPFLAGS += "
        "-I$(SRC_PATH)/libavcodec/audio_vivid -DAVS3_LIBRARY_ONLY\n"
        "libavcodec/audio_vivid/%.o: CFLAGS += -Wno-missing-prototypes\n",
    )

    insert_once(
        source / "libavformat" / "isom_tags.c",
        "{ AV_CODEC_ID_AV3A,",
        "    { AV_CODEC_ID_AAC,             MKTAG('m', 'p', '4', 'a') },",
        "    { AV_CODEC_ID_AV3A,            MKTAG('a', 'v', '3', 'a') }, /* Audio Vivid */\n"
        "    { AV_CODEC_ID_AAC,             MKTAG('m', 'p', '4', 'a') },",
    )

    insert_once(
        source / "libavformat" / "mpegts.h",
        "STREAM_TYPE_AUDIO_AV3A",
        "#define STREAM_TYPE_VIDEO_AVS3      0xd4",
        "#define STREAM_TYPE_VIDEO_AVS3      0xd4\n"
        "#define STREAM_TYPE_AUDIO_AV3A      0xd5",
    )

    insert_once(
        source / "libavformat" / "mpegts.c",
        "{ STREAM_TYPE_AUDIO_AV3A,",
        "    { STREAM_TYPE_VIDEO_AVS3,     AVMEDIA_TYPE_VIDEO, AV_CODEC_ID_AVS3       },",
        "    { STREAM_TYPE_VIDEO_AVS3,     AVMEDIA_TYPE_VIDEO, AV_CODEC_ID_AVS3       },\n"
        "    { STREAM_TYPE_AUDIO_AV3A,     AVMEDIA_TYPE_AUDIO, AV_CODEC_ID_AV3A       },",
    )

    print(f"Audio Vivid sources prepared in {source}")


if __name__ == "__main__":
    main()
