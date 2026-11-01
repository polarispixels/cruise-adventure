"""How every game clip is encoded (Technical Optimization Spec, T1): sized for
the tablet's screen, 854x480 at 24 fps, Theora at about 1.2 Mbps, Vorbis
audio at 64 kbps. The source clips stay full quality in the art project; only
the game copy is reduced. If 480p looks blocky on the tablet, the spec's
step up is 960x540 at 1.5 Mbps.
"""
SIZE = (854, 480)
FPS = 24
VIDEO_BITRATE = "1200k"
AUDIO_BITRATE = "64k"


def ffmpeg_args(src: str, dst: str, start: float = 0.0, cover: list | None = None) -> list[str]:
    """ffmpeg arguments after the image name. start: skip this many seconds (a
    clip delivered with another stuck on the front). cover: [x, y, w, h] in the
    source's pixels to blur away (burned-in caption text)."""
    vf = "scale=%d:%d" % SIZE
    if cover:
        vf = "delogo=x=%d:y=%d:w=%d:h=%d," % tuple(cover) + vf
    return ["-y", "-loglevel", "error", "-ss", str(start), "-i", src, "-vf", vf, "-r", str(FPS),
            "-c:v", "libtheora", "-b:v", VIDEO_BITRATE, "-c:a", "libvorbis", "-b:a", AUDIO_BITRATE, dst]
