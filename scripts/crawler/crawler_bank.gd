class_name CrawlerBank
extends Control
## The bank at the hub (design §GJ.2, queue 117; data/crawler.json
## hub.bank), like PSO's: what is in it is never lost (death takes only
## what you carry, §GJ.1). Its contents live in the game's save
## (CrawlerSave.data.bank: {"items": [...], "currency": n}, §FK).
##
## The panel: what you carry on the left (the carry slots and the left
## hand's strip), what the bank holds on the right; click a thing to move
## it across. Esc or the interact button closes it. Who keeps the bank is
## open (§GJ.2): a lidded store-basket by the hub fire (HubCamp.bank_node).

static var B: Dictionary = (Tuning.table("crawler").get("hub", {}) as Dictionary).get("bank", {})

var main: CrawlerMain
var _left: ItemList
var _right: ItemList
var _cur: Label
var _rows_left: Array = []


static func store() -> Dictionary:
	var b: Variant = CrawlerSave.data.get("bank", null)
	if not b is Dictionary:
		b = {"items": [], "currency": 0}
		CrawlerSave.data["bank"] = b
	return b


static func items() -> Array:
	return store().get("items", [])


static func currency() -> int:
	return int(store().get("currency", 0))


static func capacity() -> int:
	return int(B.get("capacity", 60))


## Put the thing from `inv` (`where` "carried" or "strip", index `i`) in the
## bank; true if it went in.
static func deposit(inv: Inventory, where: String, i: int) -> bool:
	var arr: Array = inv.carried if where == "carried" else inv.strip
	if i < 0 or i >= arr.size() or arr[i] == null or items().size() >= capacity():
		return false
	var it: Dictionary = arr[i]
	arr[i] = null
	(store().items as Array).append(it)
	CrawlerSave.save()
	return true


## Take bank thing `i` back into `inv`; true if there was room.
static func withdraw(inv: Inventory, i: int) -> bool:
	var list := items()
	if i < 0 or i >= list.size():
		return false
	if not inv.add(list[i]):
		return false
	list.remove_at(i)
	CrawlerSave.save()
	return true


## Currency in (teeth, §FZ.3; not built yet: the slot is ready).
static func deposit_currency(n: int) -> void:
	store()["currency"] = currency() + maxi(n, 0)
	CrawlerSave.save()


# --- The panel ------------------------------------------------------------------------

func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "BankPanel"
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 300)
	position = Vector2(-280, -150)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = custom_minimum_size
	add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(12, 36)
	row.size = Vector2(536, 250)
	add_child(row)
	var title := Label.new()
	title.text = "Carried            ·            The store by the fire"
	title.position = Vector2(12, 8)
	add_child(title)
	_left = ItemList.new()
	_left.custom_minimum_size = Vector2(262, 230)
	_left.item_clicked.connect(func(idx, _p, _b): _put(idx))
	row.add_child(_left)
	_right = ItemList.new()
	_right.custom_minimum_size = Vector2(262, 230)
	_right.item_clicked.connect(func(idx, _p, _b): _take(idx))
	row.add_child(_right)
	_cur = Label.new()
	_cur.position = Vector2(12, 272)
	_cur.size = Vector2(536, 22)
	_cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cur)


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	GameLog.add(str(B.get("log_open", "You open the store by the fire.")), "world")


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	var inv := main.player.inventory
	_left.clear()
	_rows_left.clear()
	for pair in [["carried", inv.carried], ["strip", inv.strip]]:
		for i in (pair[1] as Array).size():
			var it = pair[1][i]
			if it is Dictionary:
				_left.add_item(Inventory.title(it))
				_rows_left.append([pair[0], i])
	_right.clear()
	for it in items():
		_right.add_item(Inventory.title(it))
	_cur.text = "%s in store: %d   ·   %d of %d places" % [str(B.get("currency", "teeth")).capitalize(), currency(), items().size(), capacity()]


func _put(row: int) -> void:
	if row < 0 or row >= _rows_left.size():
		return
	deposit(main.player.inventory, str(_rows_left[row][0]), int(_rows_left[row][1]))
	refresh()


func _take(row: int) -> void:
	withdraw(main.player.inventory, row)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()
