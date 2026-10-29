"""Synthesize a placeholder spoken line with Windows SAPI, encoded to Ogg Vorbis.

Placeholder only: real recordings replace these files later with no code changes.
Usage: python3 tools/make_voice.py "Who do you want to play as?" assets/audio/who-do-you-want.ogg
"""
import subprocess
import sys
from pathlib import Path

POWERSHELL = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"


def speak(text: str, dst: Path) -> None:
    import import_art  # docker helpers; imported here to avoid a cycle at module load

    dst = Path(dst).resolve()
    wav = dst.with_suffix(".wav")
    win_wav = subprocess.run(["wslpath", "-w", str(wav)], check=True, capture_output=True, text=True).stdout.strip()
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$f = $s.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Gender -eq 'Female' } | Select-Object -First 1;"
        "if ($f) { $s.SelectVoice($f.VoiceInfo.Name) };"
        "$s.Rate = -1;"
        f"$s.SetOutputToWaveFile('{win_wav}');"
        f"$s.Speak(\"{text}\");"
        "$s.Dispose()"
    )
    subprocess.run([POWERSHELL, "-NoProfile", "-Command", script], check=True, capture_output=True)
    cli, mount = import_art.docker()
    try:
        subprocess.run(cli + [
            "run", "--rm", "-v", f"{mount(dst.parent)}:/a", import_art.FFMPEG_IMAGE, "-y", "-loglevel", "error",
            "-i", f"/a/{wav.name}", "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", f"/a/{dst.name}",
        ], check=True)
    finally:
        wav.unlink(missing_ok=True)


if __name__ == "__main__":
    speak(sys.argv[1], Path(sys.argv[2]))
