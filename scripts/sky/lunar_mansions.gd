class_name LunarMansions
## Star glyphs for the 28 Chinese lunar mansions (er shi ba xiu), drawn
## beside the moon and advancing one mansion per in-game day (DESIGN.md
## "Moon phase and mansions").
##
## Star counts follow the traditional asterisms. The layouts are
## approximate hand-placed shapes modeled on the matching Western stars
## (e.g. Mao = the Pleiades cluster, Shen = Orion, Xin = Antares and its
## two neighbors, Wei (tail) = the hook of Scorpius), in a -1..1 box with
## +y up. They are NOT catalogue positions: for exact patterns, replace
## each entry with its stars' RA/Dec projected into this box. The sky
## shader draws each glyph as points joined in order.

const MAX_STARS := 24

## Beast group tints: Azure Dragon, Black Tortoise (drawn as deep indigo
## so it reads against the night sky), White Tiger, Vermilion Bird.
const BEAST_COLORS: Array[Color] = [
	Color(0.35, 0.65, 1.0),
	Color(0.55, 0.45, 0.95),
	Color(0.95, 0.96, 1.0),
	Color(1.0, 0.4, 0.22),
]

const PATTERNS := [
	# Azure Dragon (east)
	[Vector2(0, 0.6), Vector2(0.1, -0.6)], # Jiao
	[Vector2(-0.7, 0.3), Vector2(-0.2, 0.55), Vector2(0.3, 0.4), Vector2(0.7, -0.1)], # Kang
	[Vector2(-0.6, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.6), Vector2(0.6, -0.4)], # Di
	[Vector2(0.05, 0.75), Vector2(0.0, 0.25), Vector2(-0.05, -0.25), Vector2(-0.1, -0.75)], # Fang
	[Vector2(-0.6, 0.2), Vector2(0, 0), Vector2(0.6, 0.15)], # Xin
	[Vector2(-0.8, 0.8), Vector2(-0.6, 0.4), Vector2(-0.45, 0.0), Vector2(-0.35, -0.4), Vector2(-0.1, -0.7),
		Vector2(0.25, -0.8), Vector2(0.55, -0.6), Vector2(0.6, -0.25), Vector2(0.4, -0.05)], # Wei (tail)
	[Vector2(-0.6, 0.5), Vector2(0.5, 0.6), Vector2(0.6, -0.5), Vector2(-0.4, -0.6)], # Ji
	# Black Tortoise (north)
	[Vector2(-0.8, 0.3), Vector2(-0.35, 0.35), Vector2(0.05, 0.3), Vector2(0.15, -0.3), Vector2(0.6, -0.4), Vector2(0.7, 0.2)], # Dou
	[Vector2(-0.6, 0.6), Vector2(-0.3, 0.3), Vector2(0.0, 0.0), Vector2(0.4, -0.2), Vector2(0.2, -0.6), Vector2(-0.3, -0.4)], # Niu
	[Vector2(-0.5, 0.4), Vector2(0.4, 0.5), Vector2(0.5, -0.3), Vector2(-0.4, -0.4)], # Nu
	[Vector2(0, 0.5), Vector2(0.1, -0.5)], # Xu
	[Vector2(-0.7, -0.3), Vector2(0, 0.4), Vector2(0.7, -0.1)], # Wei (rooftop)
	[Vector2(0, 0.6), Vector2(0, -0.6)], # Shi
	[Vector2(0.1, 0.6), Vector2(-0.1, -0.6)], # Bi (wall)
	# White Tiger (west)
	[Vector2(0, 0.9), Vector2(0.4, 0.8), Vector2(0.7, 0.55), Vector2(0.85, 0.2), Vector2(0.85, -0.2), Vector2(0.7, -0.55),
		Vector2(0.4, -0.8), Vector2(0, -0.9), Vector2(-0.4, -0.8), Vector2(-0.7, -0.55), Vector2(-0.85, -0.2),
		Vector2(-0.85, 0.2), Vector2(-0.7, 0.55), Vector2(-0.4, 0.8), Vector2(-0.15, 0.3), Vector2(0.2, -0.2)], # Kui
	[Vector2(-0.6, -0.2), Vector2(0.1, 0.1), Vector2(0.6, 0.4)], # Lou
	[Vector2(-0.4, -0.3), Vector2(0.4, -0.3), Vector2(0, 0.4)], # Wei (stomach)
	[Vector2(0, 0.3), Vector2(0.25, 0.15), Vector2(0.15, -0.1), Vector2(-0.1, -0.15), Vector2(-0.3, 0.05),
		Vector2(-0.15, 0.25), Vector2(0.05, 0.05)], # Mao (Pleiades)
	[Vector2(-0.7, 0.7), Vector2(-0.4, 0.2), Vector2(-0.15, -0.3), Vector2(0.05, -0.6), Vector2(0.25, -0.3),
		Vector2(0.45, 0.1), Vector2(0.7, 0.6), Vector2(0.55, 0.35)], # Bi (net, Hyades)
	[Vector2(-0.2, -0.15), Vector2(0.2, -0.15), Vector2(0, 0.2)], # Zi
	[Vector2(-0.55, 0.8), Vector2(0.6, 0.75), Vector2(0.2, 0.1), Vector2(0, 0.0), Vector2(-0.2, -0.1),
		Vector2(-0.6, -0.8), Vector2(0.55, -0.75), Vector2(0.0, -0.3), Vector2(0.02, -0.45), Vector2(0.04, -0.6)], # Shen (Orion)
	# Vermilion Bird (south)
	[Vector2(-0.5, 0.8), Vector2(-0.5, 0.25), Vector2(-0.5, -0.3), Vector2(-0.5, -0.8),
		Vector2(0.5, 0.8), Vector2(0.5, 0.25), Vector2(0.5, -0.3), Vector2(0.5, -0.8)], # Jing (well)
	[Vector2(-0.4, 0.4), Vector2(0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, -0.4)], # Gui
	[Vector2(-0.8, 0.2), Vector2(-0.55, 0.5), Vector2(-0.3, 0.3), Vector2(-0.05, 0.0), Vector2(0.2, -0.25),
		Vector2(0.45, -0.05), Vector2(0.7, 0.2), Vector2(0.8, -0.3)], # Liu (willow)
	[Vector2(-0.8, 0.4), Vector2(-0.5, 0.25), Vector2(-0.2, 0.05), Vector2(0.05, -0.1), Vector2(0.3, -0.05),
		Vector2(0.55, -0.25), Vector2(0.8, -0.4)], # Xing
	[Vector2(-0.6, 0.5), Vector2(0.0, 0.7), Vector2(0.6, 0.45), Vector2(0.5, -0.3), Vector2(0.0, -0.6), Vector2(-0.5, -0.3)], # Zhang
	[Vector2(-0.9, 0.5), Vector2(-0.75, 0.2), Vector2(-0.6, -0.1), Vector2(-0.45, -0.35), Vector2(-0.3, -0.55),
		Vector2(-0.15, -0.3), Vector2(0.0, -0.05), Vector2(0.15, -0.3), Vector2(0.3, -0.55), Vector2(0.45, -0.35),
		Vector2(0.6, -0.1), Vector2(0.75, 0.2), Vector2(0.9, 0.5), Vector2(0.6, 0.55), Vector2(0.3, 0.45),
		Vector2(0.0, 0.4), Vector2(-0.3, 0.45), Vector2(-0.6, 0.55), Vector2(0.0, 0.15), Vector2(-0.2, 0.2),
		Vector2(0.2, 0.2), Vector2(0.0, 0.7)], # Yi (wings)
	[Vector2(-0.5, 0.35), Vector2(0.45, 0.45), Vector2(0.55, -0.4), Vector2(-0.45, -0.45)], # Zhen
]


static func stars(mansion: int) -> Array:
	return PATTERNS[posmod(mansion, 28)]


static func tint(mansion: int) -> Color:
	return BEAST_COLORS[Astro.beast_index(posmod(mansion, 28))]
