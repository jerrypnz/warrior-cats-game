extends Node
## Plays sound effects from the sound library: Sfx.play("collect")

const NAMES := ["jump", "land", "collect", "hurt", "enemy_bonk", "win", "lose", "click", "select", "powerup"]

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _sounds.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.pitch_scale = pitch
			player.volume_db = volume_db
			player.play()
			return
