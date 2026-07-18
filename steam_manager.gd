# steam_manager.gd
extends Node

var _initialized: bool = false

func _ready():
	var init = Steam.steamInitEx()
	if init["status"] != Steam.STEAM_API_INIT_RESULT_OK:
		print("Steam初期化失敗: ", init)
	else:
		print("Steam初期化OK")
		_initialized = true

func _process(_delta):
	Steam.run_callbacks()  # 毎フレーム必須

## 実績を解除する。Steamが未初期化（Steamクライアント未起動等）の場合は何もしない。
## api_name: Steamworks管理画面に登録済みの実績API名（文字列ID）
func unlock_achievement(api_name: String) -> void:
	if not _initialized or api_name == "":
		return
	Steam.setAchievement(api_name)
	Steam.storeStats()
