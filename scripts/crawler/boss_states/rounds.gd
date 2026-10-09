extends BossState
## 'rounds' (design §FM.1; data/boss_pool.json pools.<boss>.rounds): the
## boss's built behaviour, wrapped and not rewritten (queues 49, 56, 57:
## its rounds from dead end to dead end, coiling in each, noticing you, the
## chase, the torch's hold, the strike, the edge of the light, leaving a
## room lit round it). Boss.rounds_tick is that behaviour, unchanged, so a
## pool with only 'rounds' plays exactly as the boss did before the pool.


## From another state: back on its rounds from where that one left it
## (coiling or prowling, it carries on; anything else, it sets off on its
## next round). From nothing or from itself, nothing changes.
func enter(boss: Boss, from: String) -> void:
	if from == "" or from == id:
		return
	boss.resume_rounds()


func tick(boss: Boss, delta: float) -> void:
	boss.rounds_tick(delta)


func built() -> bool:
	return true
