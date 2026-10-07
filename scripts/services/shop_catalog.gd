extends RefCounted
## Single source for shop quantities and prices. USD amounts are MOCK display
## prices, in integer cents; real purchases must use verified platform products.

const PACK_COUNT := 6
const DIAMONDS_PER_STEP := 10
const USD_CENTS_PER_STEP := 99
const EXCHANGE_DIAMONDS_PER_STEP := 1
const COINS_PER_DIAMOND := 100


static func diamond_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for tier in range(1, PACK_COUNT + 1):
		offers.append({
			"id": "diamonds_%d" % tier,
			"quantity": tier * DIAMONDS_PER_STEP,
			"usd_cents": tier * USD_CENTS_PER_STEP,
			"mock": true,
		})
	return offers


static func coin_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for tier in range(1, PACK_COUNT + 1):
		var diamonds := tier * EXCHANGE_DIAMONDS_PER_STEP
		offers.append({
			"id": "coins_%d" % tier,
			"quantity": diamonds * COINS_PER_DIAMOND,
			"diamond_cost": diamonds,
		})
	return offers


static func coin_offer(offer_id: String) -> Dictionary:
	for offer in coin_offers():
		if offer["id"] == offer_id:
			return offer
	return {}


static func usd_price(cents: int) -> String:
	# Integer arithmetic avoids float rounding when changing the mock strategy.
	@warning_ignore("integer_division")
	return "$%d.%02d" % [cents / 100, cents % 100]
