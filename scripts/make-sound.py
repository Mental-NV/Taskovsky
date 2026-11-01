"""Generate a short original completion chime, without external assets."""
import math
import struct
import sys
import wave

rate = 44100
duration = 0.22
samples = []
for i in range(int(rate * duration)):
    t = i / rate
    attack = min(1.0, t / 0.004)
    envelope = attack * math.exp(-t * 23) * min(1.0, (duration - t) / 0.025)
    tone = math.sin(2 * math.pi * 1046.5 * t) + 0.35 * math.sin(2 * math.pi * 1567.98 * t)
    samples.append(struct.pack('<h', int(10000 * envelope * tone)))
with wave.open(sys.argv[1], 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(b''.join(samples))
