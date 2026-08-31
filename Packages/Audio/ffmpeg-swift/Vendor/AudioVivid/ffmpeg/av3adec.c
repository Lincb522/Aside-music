/*
 * AVS3-P3 / Audio Vivid decoder bridge for FFmpeg.
 *
 * The codec core is kept in audio_vivid/ and linked directly because iOS does
 * not permit loading the reference Linux shared objects at runtime.
 */

#include <string.h>
#include <stdint.h>

#include "libavutil/channel_layout.h"
#include "libavutil/error.h"
#include "libavutil/mem.h"

#include "avcodec.h"
#include "codec_internal.h"
#include "decode.h"

#include "audio_vivid/avs3_cnst_com.h"
#include "audio_vivid/avs3_decoder_interface.h"
#include "audio_vivid/avs3_options.h"

#define AV3A_MAX_PENDING_SIZE (2 * 1024 * 1024)
#define AV3A_MAX_PCM_SIZE     (MAX_CHANNELS * FRAME_LEN * (int)sizeof(int16_t))

typedef struct AV3ADecodeContext {
    AVS3DecoderHandle decoder;
    uint8_t *pending;
    size_t pending_size;
    int first_frame;
    uint8_t *pcm;
} AV3ADecodeContext;

static void av3a_set_layout(AVChannelLayout *layout, int channels, int channel_config)
{
    av_channel_layout_uninit(layout);

    if (channels == 1) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_MONO;
    } else if (channels == 2) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;
    } else if (channels == 4 && channel_config == CHANNEL_CONFIG_MC_4_0) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_4POINT0;
    } else if (channels == 6 && channel_config == CHANNEL_CONFIG_MC_5_1) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_5POINT1;
    } else if (channels == 8 && channel_config == CHANNEL_CONFIG_MC_7_1) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_7POINT1;
    } else if (channels == 8 && channel_config == CHANNEL_CONFIG_MC_5_1_2) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_5POINT1POINT2;
    } else if (channels == 10 && channel_config == CHANNEL_CONFIG_MC_5_1_4) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_5POINT1POINT4_BACK;
    } else if (channels == 10 && channel_config == CHANNEL_CONFIG_MC_7_1_2) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_7POINT1POINT2;
    } else if (channels == 12 && channel_config == CHANNEL_CONFIG_MC_7_1_4) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_7POINT1POINT4_BACK;
    } else if (channels == 16 && channel_config == CHANNEL_CONFIG_HOA_ORDER3) {
        *layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_HEXADECAGONAL;
    } else {
        layout->order = AV_CHANNEL_ORDER_UNSPEC;
        layout->nb_channels = channels;
    }
}

static int av3a_reset(AV3ADecodeContext *s)
{
    if (s->decoder)
        avs3_destroy_decoder(s->decoder);

    s->decoder = avs3_create_decoder();
    if (!s->decoder)
        return AVERROR(ENOMEM);

    s->pending_size = 0;
    s->first_frame = 1;
    return 0;
}

static av_cold int av3a_decode_init(AVCodecContext *avctx)
{
    AV3ADecodeContext *s = avctx->priv_data;

    avctx->sample_fmt = AV_SAMPLE_FMT_S16;
    s->pcm = av_malloc(AV3A_MAX_PCM_SIZE);
    if (!s->pcm)
        return AVERROR(ENOMEM);

    return av3a_reset(s);
}

static void av3a_decode_flush(AVCodecContext *avctx)
{
    AV3ADecodeContext *s = avctx->priv_data;
    if (av3a_reset(s) < 0)
        av_log(avctx, AV_LOG_ERROR, "Unable to reset Audio Vivid decoder\n");
}

static av_cold int av3a_decode_close(AVCodecContext *avctx)
{
    AV3ADecodeContext *s = avctx->priv_data;

    if (s->decoder)
        avs3_destroy_decoder(s->decoder);
    s->decoder = NULL;
    av_freep(&s->pending);
    av_freep(&s->pcm);
    s->pending_size = 0;
    return 0;
}

static int av3a_append_packet(AV3ADecodeContext *s, const AVPacket *packet)
{
    uint8_t *resized;
    size_t required;

    if (!packet->size)
        return 0;
    if (packet->size < 0 || s->pending_size > AV3A_MAX_PENDING_SIZE - packet->size)
        return AVERROR_INVALIDDATA;

    required = s->pending_size + packet->size;
    resized = av_realloc(s->pending, required);
    if (!resized)
        return AVERROR(ENOMEM);

    s->pending = resized;
    memcpy(s->pending + s->pending_size, packet->data, packet->size);
    s->pending_size = required;
    return 0;
}

static void av3a_consume(AV3ADecodeContext *s, size_t length)
{
    if (length >= s->pending_size) {
        s->pending_size = 0;
        return;
    }

    memmove(s->pending, s->pending + length, s->pending_size - length);
    s->pending_size -= length;
}

static int av3a_receive_one_frame(AVCodecContext *avctx, AVFrame *frame,
                                  int *got_frame)
{
    AV3ADecodeContext *s = avctx->priv_data;

    while (s->pending_size >= MAX_NBYTES_FRAME_HEADER) {
        int header_consumed = 0;
        int payload_consumed = 0;
        int output_size = 0;
        int ret;
        int channels;
        int sample_rate;
        int sample_count;
        size_t consumed;

        ret = parse_header(s->decoder, s->pending, (int)s->pending_size,
                           s->first_frame, &header_consumed, NULL);
        if (ret == AVS3_DATA_NOT_ENOUGH)
            return 0;
        if (ret != AVS3_TRUE) {
            av3a_consume(s, header_consumed > 0 ? header_consumed : 1);
            continue;
        }
        if (header_consumed < 0 || (size_t)header_consumed > s->pending_size)
            return AVERROR_INVALIDDATA;
        if (s->decoder->numChansOutput <= 0 ||
            s->decoder->numChansOutput > MAX_CHANNELS ||
            s->decoder->outputFs <= 0)
            return AVERROR_INVALIDDATA;

        ret = avs3_decode(s->decoder, s->pending + header_consumed,
                          (int)s->pending_size - header_consumed,
                          s->pcm, &output_size, &payload_consumed);
        if (ret == AVS3_DATA_NOT_ENOUGH)
            return 0;
        if (ret != AVS3_TRUE || output_size <= 0 || payload_consumed < 0)
            return AVERROR_INVALIDDATA;
        if (output_size > AV3A_MAX_PCM_SIZE)
            return AVERROR_INVALIDDATA;

        consumed = (size_t)header_consumed + payload_consumed;
        if (consumed > s->pending_size)
            return AVERROR_INVALIDDATA;

        channels = s->decoder->numChansOutput;
        sample_rate = s->decoder->outputFs;
        if (channels <= 0 || channels > MAX_CHANNELS || sample_rate <= 0 ||
            output_size % (channels * (int)sizeof(int16_t)) != 0)
            return AVERROR_INVALIDDATA;

        sample_count = output_size / (channels * (int)sizeof(int16_t));
        av3a_set_layout(&avctx->ch_layout, channels,
                        s->decoder->channelNumConfig);
        avctx->sample_rate = sample_rate;
        avctx->sample_fmt = AV_SAMPLE_FMT_S16;

        frame->nb_samples = sample_count;
        frame->sample_rate = sample_rate;
        frame->format = AV_SAMPLE_FMT_S16;
        if ((ret = av_channel_layout_copy(&frame->ch_layout,
                                          &avctx->ch_layout)) < 0)
            return ret;
        if ((ret = ff_get_buffer(avctx, frame, 0)) < 0)
            return ret;

        memcpy(frame->data[0], s->pcm, output_size);
        av3a_consume(s, consumed);
        s->first_frame = 0;
        *got_frame = 1;
        return 0;
    }

    return 0;
}

static int av3a_decode_frame(AVCodecContext *avctx, AVFrame *frame,
                             int *got_frame, AVPacket *packet)
{
    AV3ADecodeContext *s = avctx->priv_data;
    int ret;

    *got_frame = 0;
    ret = av3a_append_packet(s, packet);
    if (ret < 0)
        return ret;

    ret = av3a_receive_one_frame(avctx, frame, got_frame);
    if (ret < 0) {
        av_log(avctx, AV_LOG_ERROR, "Invalid Audio Vivid frame\n");
        av3a_decode_flush(avctx);
        return ret;
    }

    return packet->size;
}

const FFCodec ff_av3a_decoder = {
    .p.name           = "av3a",
    CODEC_LONG_NAME("AVS3-P3 / Audio Vivid"),
    .p.type           = AVMEDIA_TYPE_AUDIO,
    .p.id             = AV_CODEC_ID_AV3A,
    .priv_data_size   = sizeof(AV3ADecodeContext),
    .init             = av3a_decode_init,
    .flush            = av3a_decode_flush,
    .close            = av3a_decode_close,
    FF_CODEC_DECODE_CB(av3a_decode_frame),
    .p.capabilities   = AV_CODEC_CAP_DR1 | AV_CODEC_CAP_CHANNEL_CONF,
    .caps_internal    = FF_CODEC_CAP_INIT_CLEANUP,
    CODEC_SAMPLEFMTS(AV_SAMPLE_FMT_S16),
};
