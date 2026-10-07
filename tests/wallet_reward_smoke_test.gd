extends SceneTree

const PlayerWalletScript = preload("res://scripts/services/player_wallet.gd")
const HiddenDiamondPolicyScript = preload("res://scripts/services/hidden_diamond_policy.gd")
const ShopCatalogScript = preload("res://scripts/services/shop_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var diamond_offers := ShopCatalogScript.diamond_offers()
	var coin_offers := ShopCatalogScript.coin_offers()
	assert(diamond_offers.size() == 6 and coin_offers.size() == 6, "Both shop tabs should generate six packages")
	assert(diamond_offers[0]["quantity"] == 10 and diamond_offers[5]["quantity"] == 60, "Mock diamond tiers should range from 10 to 60")
	assert(ShopCatalogScript.usd_price(diamond_offers[5]["usd_cents"]) == "$5.94", "USD prices must format integer cents, including fractional dollars")
	assert(coin_offers[5]["quantity"] == 600 and coin_offers[5]["diamond_cost"] == 6, "The largest coin pack should exchange six diamonds for 600 coins")
	assert(ShopCatalogScript.coin_offer("diamonds_1").is_empty(), "A USD offer cannot be submitted as a coin exchange")
	var wallet = PlayerWalletScript.new(2)
	wallet.diamond_balance = 2
	var exchanged: Dictionary = wallet.exchange_diamonds_for_coins(1, 100)
	assert(bool(exchanged.get("success", false)), "One diamond should exchange successfully")
	assert(wallet.balance == 102 and wallet.diamond_balance == 1, "Exchange should add 100 coins and spend one diamond")
	var rejected: Dictionary = wallet.exchange_diamonds_for_coins(2, 100)
	assert(not bool(rejected.get("success", false)), "Exchange cannot spend more diamonds than owned")
	assert(wallet.balance == 102 and wallet.diamond_balance == 1, "Rejected exchange must not mutate balances")
	var progress := HiddenDiamondPolicyScript.normalize({})
	assert(is_equal_approx(HiddenDiamondPolicyScript.dynamic_ratio(progress, "time"), 0.9), "Initial hidden challenge ratio must be 0.9")
	assert(HiddenDiamondPolicyScript.event_id("composite", 11) == "composite_round_11", "The independent event identity must not depend on a modulo-10 milestone")
	print("WALLET AND SHOP CATALOG TEST PASSED")
	quit()
