# steam_manager.gd
extends Node

func _ready():
    var init = Steam.steamInitEx()
    if init["status"] != Steam.STEAM_API_INIT_RESULT_OK:
        print("Steam初期化失敗: ", init)
    else:
        print("Steam初期化OK")

func _process(_delta):
    Steam.run_callbacks()  # 毎フレーム必須