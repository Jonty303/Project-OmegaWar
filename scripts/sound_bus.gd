extends Node

# Subtle, self-contained 22.05kHz synthesized effects. No external audio
# files, samples or dependencies. All effects are quieter than conventional
# arcade sounds; rebound is deliberately barely audible.
const RATE := 22050
const VOLUMES := {"pulse":-26.0, "missile":-24.0, "explosion":-21.0, "rebound":-36.0}
const LENGTHS := {"pulse":0.060, "missile":0.14, "explosion":0.30, "rebound":0.043}
const MIN_INTERVAL := {"pulse":0.055, "missile":0.09, "explosion":0.075, "rebound":0.16}
var streams: Dictionary = {}
var voices: Dictionary = {}
var indices: Dictionary = {}
var since: Dictionary = {}

func _ready() -> void:
	for kind in VOLUMES:
		streams[kind] = synth(kind)
		voices[kind] = []
		indices[kind] = 0
		since[kind] = 100.0
		for i in range(4 if kind != "rebound" else 2):
			var voice := AudioStreamPlayer.new()
			voice.stream = streams[kind]
			voice.volume_db = VOLUMES[kind]
			add_child(voice)
			voices[kind].append(voice)

func advance(delta: float) -> void:
	for kind in since:
		since[kind] += delta

func play(kind: String) -> void:
	if not voices.has(kind) or since[kind] < MIN_INTERVAL[kind]:
		return
	since[kind] = 0.0
	var slot: int = indices[kind]
	var voice: AudioStreamPlayer = voices[kind][slot]
	voice.stop()
	voice.play()
	indices[kind] = (slot + 1) % voices[kind].size()

func synth(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var count: int = int(float(LENGTHS[kind]) * RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for n in range(count):
		var time: float = float(n) / RATE
		var progress: float = float(n) / float(count)
		var env: float = pow(1.0 - progress, 2.6)
		var tone := 0.0
		match kind:
			"pulse":
				tone = sin(TAU * (930.0 * time - 330.0 * time * progress))
			"missile":
				tone = 0.64 * sin(TAU * (410.0 * time - 185.0 * time * progress)) + 0.2 * sin(TAU * 125.0 * time)
			"explosion":
				var noise: float = sin(float(n) * 88.719) * sin(float(n) * 12.437)
				tone = noise * 0.68 + 0.25 * sin(TAU * (100.0 * time - 50.0 * time * progress))
			"rebound":
				tone = sin(TAU * (350.0 * time + 140.0 * time * progress))
		var sample: int = roundi(clampf(tone * env * 0.56, -1.0, 1.0) * 32767.0)
		pcm[n * 2] = sample & 255
		pcm[n * 2 + 1] = (sample >> 8) & 255
	stream.data = pcm
	return stream
