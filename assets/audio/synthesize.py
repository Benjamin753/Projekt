"""Render the original CC0 sound set with Python 3 and NumPy."""
from pathlib import Path
import wave

import numpy as np


RATE = 24000
OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(814)
TAU = 2 * np.pi


def clock(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def noise(t):
    return RNG.uniform(-1, 1, len(t))


def resonance(t, frequency, decay):
    return np.sin(TAU * frequency * t) * np.exp(-t * decay)


def tap(t, modes, grit, grit_decay):
    impact = sum(level * resonance(t, freq, decay) for freq, decay, level in modes)
    return impact + grit * noise(t) * np.exp(-t * grit_decay)


def pitch(frequency, t, bend, decay):
    turns = frequency * t + bend * (1 - np.exp(-decay * t)) / decay
    return np.sin(TAU * turns)


def strike(t, freq, strength=1):
    attack = 1 - np.exp(-900 * t)
    string = sum(
        gain * resonance(t, freq * harmonic, decay)
        for harmonic, gain, decay in [(1, .66, 4), (2, .24, 7), (3, .16, 11), (4.01, .10, 18), (6.02, .065, 27)]
    )
    pick = .13 * noise(t) * np.exp(-100 * t)
    return strength * attack * (string + pick)


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(track, sample, time, pan=0.0, wrap=False):
    start = round(time * RATE)
    gained = sample[:, None] * np.sqrt(np.array([1 - pan, 1 + pan]) / 2)
    end = min(len(track), start + len(sample))
    count = end - start
    track[start:end] += gained[:count]
    if wrap and count < len(sample):
        track[:len(sample) - count] += gained[count:]


def save(name, sample):
    pcm = np.round(np.clip(sample, -.99, .99) * 32767).astype('<i2')
    with wave.open(str(OUT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def effects():
    taps = {
        'flip_up': (.17, [(168, 60, .45), (653, 58, .17), (1633, 91, .14)], .36, 150),
        'flip_down': (.16, [(122, 53, .43), (527, 65, .21), (1418, 99, .10)], .26, 130),
        'rubber': (.18, [(142, 42, .57), (423, 56, .20), (720, 80, .09)], .17, 130),
        'rail': (.28, [(690, 27, .19), (1293, 25, .24), (2519, 35, .18), (4277, 42, .16)], .21, 95),
    }
    for name, (duration, modes, grit, decay) in taps.items():
        save(name, tap(clock(duration), modes, grit, decay))

    spring = np.zeros_like(clock(.49))
    for i, at in enumerate([0, .036, .087, .153, .23, .32]):
        t = clock(.15)
        start = round(at * RATE)
        spring[start:start + len(t)] += (1 - i * .08) * tap(t, [(390 + i * 36, 38, .24), (1700 + 70 * i, 68, .12)], .13, 110)
    save('spring', spring)
    t = clock(.37)
    save('launch', tap(t, [(155, 22, .42), (857, 27, .21), (1809, 38, .18)], .37, 122)
         + .12 * pitch(270, t, 310, 20) * np.exp(-20 * t))
    t = clock(.26)
    save('bumper', .51 * pitch(110, t, 255, 48) * np.exp(-t * 21)
         + tap(t, [(735, 46, .18), (1189, 68, .14)], .34, 94))
    t = clock(.48)
    save('drain', .43 * pitch(48, t, 206, 10) * np.exp(-t * 7) * (1 - np.exp(-t * 95))
         + .12 * noise(t) * np.exp(-t * 11) * (1 + np.sin(TAU * 25 * t)))
    for name, notes, interval in [
        ('purchase', [64, 71], .076), ('extra_life', [64, 68, 71, 76], .083),
        ('game_over', [64, 62, 59, 52], .155),
    ]:
        cue = np.zeros((round(RATE * (len(notes) * interval + .35)), 2))
        for i, key in enumerate(notes):
            t = clock(.32)
            add(cue, strike(t, note(key), .47) * np.exp(-4 * t), i * interval)
        save(name, cue)


def music():
    beat = 60 / 116
    # Twelve-bar E shuffle with an alternating bass, muted strum and a short turnaround.
    roots = [40, 40, 40, 40, 45, 45, 40, 40, 47, 45, 40, 47]
    track = np.zeros((round(RATE * beat * 4 * len(roots)), 2))
    for bar, root in enumerate(roots):
        chord = [root + 12, root + 16, root + 19, root + 22]
        for step, interval in enumerate([0, 7, 9, 7]):
            t = clock(.49)
            bass = strike(t, note(root - 12 + interval)) * np.exp(-3 * t)
            at = (bar * 4 + step) * beat
            add(track, bass * .18, at, -.1, wrap=True)
            t = clock(.25)
            kick = pitch(50, t, 48, 32) * np.exp(-18 * t)
            add(track, kick * (.14 if step % 2 == 0 else .06), at, wrap=True)
            if step % 2 == 1:
                t = clock(.19)
                brush = np.diff(noise(np.arange(len(t) + 1))) * np.exp(-t * 22)
                add(track, .053 * brush + .05 * resonance(t, 181, 28), at, .15, wrap=True)
            for swing in [0, .66]:
                t = clock(.11)
                tick = np.diff(noise(np.arange(len(t) + 1))) * np.exp(-t * 56)
                add(track, tick * (.031 if swing == 0 else .018), at + swing * beat, .29, wrap=True)
            for string, key in enumerate(chord):
                t = clock(.26)
                guitar = strike(t, note(key)) * np.exp(-9 * t)
                add(track, guitar * .062, at + .66 * beat + string * .011, -.38, wrap=True)
        if bar in [1, 3, 5, 7, 10, 11]:
            intervals = [3, 4, 7, 9] if bar != 11 else [10, 9, 7, 4]
            for i, interval in enumerate(intervals):
                t = clock(.45)
                lead = strike(t, note(root + 12 + interval)) * np.exp(-2 * t)
                at = (bar * 4 + 2 + [0, .66, 1, 1.66][i]) * beat
                add(track, lead * .125, at, .39, wrap=True)
                add(track, lead * .023, at + beat * .33, -.22, wrap=True)
    save('western_shuffle', track)


if __name__ == '__main__':
    effects()
    music()
