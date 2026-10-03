class_name EngineReport
## What the game runs on, and whether its shaders built (design §CG: the
## game draws the same on every machine). Mike's 2 Oct 22:52 play: the
## plants drew grey on his Mac because a newer Godot rejected the plant
## shader (too many varyings) and Godot then draws its grey default
## material without a word on screen. So the game says so itself:
##   - summary(): the Godot version, the renderer and its driver (Vulkan
##     or Metal), and the GPU, for F3 and the log's first line;
##   - check_shaders() at boot: every world (spatial) shader in
##     res://shaders that declares uniforms but lists none
##     (Shader.get_shader_uniform_list() empty) failed to compile: one
##     push_error each, and the F3 line "Shaders: all N built" or
##     "Shaders: foliage FAILED (Godot x.y)".

const SHADER_DIR := "res://shaders"

## {"total": N, "failed": ["foliage", ...]} after check_shaders().
static var result := {}


static func version_short() -> String:
	var v := Engine.get_version_info()
	return "%d.%d" % [int(v.major), int(v.minor)]


static func version() -> String:
	return "Godot %s" % str(Engine.get_version_info().get("string", version_short()))


## The renderer ("Forward+", "Mobile", "Compatibility"), its driver
## ("Vulkan", "Metal", "OpenGL", "D3D12") and the GPU.
static func summary() -> String:
	var renderer := renderer_name()
	var driver := driver_name()
	var gpu := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var api := RenderingServer.get_video_adapter_api_version()
	var g := gpu if gpu != "" else "no GPU (headless)"
	if vendor != "" and vendor != "Unknown" and gpu.find(vendor) < 0:
		g = "%s (%s)" % [gpu, vendor]
	return "%s · %s · %s%s · %s" % [version(), renderer, driver, (" " + api) if api != "" and DisplayServer.get_name() != "headless" else "", g]


## "Forward+", "Mobile" or "Compatibility": the renderer asked for on the
## command line, else the project's (Godot 4.4 and later say which ran).
static func renderer_name() -> String:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	var args := OS.get_cmdline_args()
	var k := args.find("--rendering-method")
	if k >= 0 and k + 1 < args.size():
		method = args[k + 1]
	if RenderingServer.has_method("get_current_rendering_method"):
		method = str(RenderingServer.call("get_current_rendering_method"))
	return str({"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}.get(method, method))


## "Vulkan", "Metal", "D3D12", "OpenGL": the driver that runs (Godot 4.4
## and later say), else the one the project asks for on this OS.
static func driver_name() -> String:
	if DisplayServer.get_name() == "headless":
		return "no driver (headless)"
	var drv := ""
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		drv = str(RenderingServer.call("get_current_rendering_driver_name"))
	else:
		var compat := renderer_name() == "Compatibility"
		var base := "rendering/gl_compatibility/driver" if compat else "rendering/rendering_device/driver"
		var os_key: String = {"macOS": "macos", "Windows": "windows", "Linux": "linuxbsd", "FreeBSD": "linuxbsd", "Android": "android", "iOS": "ios"}.get(OS.get_name(), "")
		drv = str(ProjectSettings.get_setting(base + "." + os_key, ProjectSettings.get_setting(base, "opengl3" if compat else "vulkan")))
		if OS.get_name() == "macOS" and drv == "vulkan":
			drv = "vulkan (MoltenVK)"
	return str({"vulkan": "Vulkan", "vulkan (MoltenVK)": "Vulkan (MoltenVK)", "metal": "Metal", "opengl3": "OpenGL", "opengl3_angle": "OpenGL (ANGLE)", "opengl3_es": "OpenGL ES", "d3d12": "D3D12"}.get(drv, drv))


## Load every spatial shader under res://shaders and see which built.
static func check_shaders() -> Dictionary:
	var failed: Array = []
	var total := 0
	var dir := DirAccess.open(SHADER_DIR)
	if dir == null:
		result = {"total": 0, "failed": []}
		return result
	var names: Array = []
	for f in dir.get_files():
		var fname := str(f).trim_suffix(".remap")
		if fname.ends_with(".gdshader") and not names.has(fname):
			names.append(fname)
	names.sort()
	for fv in names:
		var fname: String = fv
		var path := SHADER_DIR.path_join(fname)
		var code := FileAccess.get_file_as_string(path)
		if code == "" or not _is_spatial(code):
			continue
		var declared := _declared_uniforms(code)
		if declared == 0:
			continue
		total += 1
		var sh := load(path) as Shader
		if sh == null or sh.get_shader_uniform_list().is_empty():
			var short := fname.get_basename()
			failed.append(short)
			push_error("Shader %s failed to compile on %s (%d uniforms declared, none listed): what it draws falls back to Godot's grey default material." % [fname, version(), declared])
	result = {"total": total, "failed": failed}
	return result


## The F3 line.
static func shaders_text() -> String:
	if result.is_empty():
		return "Shaders: not checked"
	var failed: Array = result.failed
	if failed.is_empty():
		return "Shaders: all %d built" % int(result.total)
	return "Shaders: %s FAILED (Godot %s)" % [", ".join(failed), version_short()]


static func _is_spatial(code: String) -> bool:
	var re := RegEx.new()
	re.compile("(?m)^\\s*shader_type\\s+spatial\\s*;")
	return re.search(code) != null


## Plain `uniform` declarations (not global or instance ones, which a
## material doesn't list).
static func _declared_uniforms(code: String) -> int:
	var re := RegEx.new()
	re.compile("(?m)^\\s*uniform\\s+")
	return re.search_all(code).size()
