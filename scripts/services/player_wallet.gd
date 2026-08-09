extends RefCounted

const CoinEconomyScript = preload("res://scripts/coin_economy.gd")

var balance := 10
var economy_progress: Dictionary = CoinEconomyScript.default_progress()
var run_exchange_count := 0


func tool_price(tool: String, display_level: int) -> int:
	return CoinEconomyScript.tool_price(tool, display_level, economy_progress, run_exchange_count)


func spend_tool(tool: String, display_level: int) -> Dictionary:
	var price := tool_price(tool, display_level)
	if balance < price:
		return {
			"success": false,
			"price": price,
			"balanceBefore": balance,
			"balanceAfter": balance,
			"shortage": price - balance
		}
	var before := balance
	balance -= price
	run_exchange_count += 1
	CoinEconomyScript.record_tool_exchange(economy_progress, tool, price)
	return {
		"success": true,
		"price": price,
		"balanceBefore": before,
		"balanceAfter": balance,
		"shortage": 0
	}


func spend(amount: int, reason: String = "") -> Dictionary:
	var price := maxi(0, amount)
	var before := balance
	if balance < price:
		return {"success": false, "amount": price, "balanceBefore": before, "balanceAfter": before, "reason": reason}
	balance -= price
	return {"success": true, "amount": price, "balanceBefore": before, "balanceAfter": balance, "reason": reason}


func grant(amount: int, reason: String = "") -> Dictionary:
	var granted := maxi(0, amount)
	var before := balance
	balance += granted
	return {"amount": granted, "balanceBefore": before, "balanceAfter": balance, "reason": reason}
