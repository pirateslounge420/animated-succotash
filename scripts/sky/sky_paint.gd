class_name SkyPaint
extends Node
## The painted sky (shaders/sky_paint.gdshader), baked once at startup
## on the GPU into two panoramas the sky shader samples every frame:
##
## * clouds (only if there is no §AG painted tile, see bake()): 2048 x
##   512 over the viewer's sky (azimuth x elevation):
##   brushy cloud banks piled over the horizon and long wispy streaks
##   higher up, stored as densities and shading so the sky shader colors
##   them for the hour and thresholds them by the weather's cover;
## * stars: 2048 x 1024 equirectangular in the celestial frame: a fixed,
##   painted starfield in three sizes (the brightest with a small glint)
##   and a milky band with dark rifts, turned with the sun.
##
## Each is an offscreen SubViewport drawn once (UPDATE_ONCE) with a
## full-size rect; the viewports stay as children so their textures live.

const BAKE_SHADER := preload("res://shaders/sky_paint.gdshader")
const CLOUD_SIZE := Vector2i(2048, 512)
const STAR_SIZE := Vector2i(2048, 1024)

var clouds: Texture2D
var stars: Texture2D


## `cloud_tile`: the §AG hand-painted cloud pano (data/look.json retro;
## 512 x 128, same channels) if there is one; the clouds are baked only
## without it.
func bake(cloud_tile: Texture2D = null) -> void:
	clouds = cloud_tile if cloud_tile else _bake(0, CLOUD_SIZE)
	stars = _bake(1, STAR_SIZE)


func _bake(layer: int, size: Vector2i) -> Texture2D:
	var vp := SubViewport.new()
	vp.name = ["CloudPanorama", "StarPanorama"][layer]
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	mat.set_shader_parameter("layer", layer)
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	return vp.get_texture()
