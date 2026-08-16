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


## INT型統計を記録する。Steamが未初期化の場合は何もしない。
## StoreStats()はunlock_achievement()末尾の呼び出しに乗せるため、ここでは呼ばない。
## stat_name: Steamworks管理画面「データ設定」に登録済みの統計API名
func set_stat_int(stat_name: String, value: int) -> void:
	if not _initialized or stat_name == "":
		return
	Steam.setStatInt(stat_name, value)
