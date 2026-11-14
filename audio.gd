extends Node

enum Cue { FLIP_UP, FLIP_DOWN, SPRING, LAUNCH, BUMPER, RUBBER, RAIL, DRAIN, PURCHASE, EXTRA_LIFE, GAME_OVER }

const SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/flip_up.wav"), preload("res://assets/audio/flip_down.wav"),
	preload("res://assets/audio/spring.wav"), preload("res://assets/audio/launch.wav"),
	preload("res://assets/audio/bumper.wav"), preload("res://assets/audio/rubber.wav"),
	preload("res://assets/audio/rail.wav"), preload("res://assets/audio/drain.wav"),
	preload("res://assets/audio/purchase.wav"), preload("res://assets/audio/extra_life.wav"),
	preload("res://assets/audio/game_over.wav"),
]
const LEVELS := [-5.0, -8.0, -7.0, -3.0, -2.0, -4.0, -9.0, -5.0, -5.0, -4.0, -5.0]
const MUSIC = preload("res://assets/audio/western_shuffle.wav")
const MUSIC_LEVEL := -7.0
var muted := false
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
@onready var music: AudioStreamPlayer = $Music
@onready var effects: Node = $Effects

func _ready() -> void:
	for index in 12:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%s" % index
		effects.add_child(voice)
		voices.append(voice)
	var loop := MUSIC.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.volume_db = MUSIC_LEVEL
	# Headless runs can still check cue routing and mute state without opening audio.
	if DisplayServer.get_name() == "headless":
		return
	music.play()

func play_cue(cue: Cue, pitch := 1.0, volume_offset := 0.0) -> void:
	if muted or not music.playing:
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = SOUNDS[cue]
	voice.volume_db = LEVELS[cue] + volume_offset
	voice.pitch_scale = pitch
	voice.play()

func set_muted(value: bool) -> void:
	muted = value
	music.stream_paused = value
	music.volume_db = -80.0 if value else MUSIC_LEVEL
	if value:
		for voice in voices:
			voice.stop()
