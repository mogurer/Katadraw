shader_type canvas_item;

// 透視変換パラメータ
// tilt_y: Y軸回転角（ラジアン）正値→右辺が奥へ
// tilt_x: X軸回転角（ラジアン）正値→下辺が奥へ
// focal_depth: 仮想カメラ距離（half_w 単位）大きいほど遠近弱く
// half_w: ビューポート幅の半分（ピクセル）透視基準スケール
uniform float tilt_y: hint_range(-0.5, 0.5) = 0.0;
uniform float tilt_x: hint_range(-0.5, 0.5) = 0.0;
uniform float focal_depth: hint_range(0.5, 20.0) = 4.0;
uniform float half_w: hint_range(100.0, 4000.0) = 960.0;

void vertex() {
	// VERTEX をスクリーン中心が原点になるように正規化
	float nx = VERTEX.x / half_w;
	float ny = VERTEX.y / half_w;
	float nz = 0.0;

	// Y軸回転（水平方向傾き）
	float cy = cos(tilt_y);
	float sy = sin(tilt_y);
	float nx2 = nx * cy - nz * sy;
	float nz2 = nx * sy + nz * cy;

	// X軸回転（垂直方向傾き）
	float cx = cos(tilt_x);
	float sxt = sin(tilt_x);
	float ny2 = ny * cx - nz2 * sxt;
	float nz3 = ny * sxt + nz2 * cx;
	float nx3 = nx2;

	// 透視投影: 仮想カメラ z=0 からパネル z=focal_depth を投影
	// 奥（+z方向）に傾いた頂点ほど z_world が大きく → 小さく見える
	float z_world = focal_depth + nz3;
	float px = nx3 / z_world * focal_depth;
	float py = ny2 / z_world * focal_depth;

	VERTEX = vec2(px * half_w, py * half_w);
}
