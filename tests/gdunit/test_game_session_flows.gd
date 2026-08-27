# Real gameplay flows against GameSession with deterministic weather rolls
# (0.0 -> rainy every day, 0.5 -> sunny every day).
class_name GameSessionFlowsGdUnitTest
extends GdUnitTestSuite

const BED := WorldContract.BED_CELL
const SHOP := WorldContract.SHOP_CELL
const SHIPPING := WorldContract.SHIPPING_CELL


func _sunny() -> GameSession:
	return GameSession.new(func() -> float: return 0.5)


func _rainy() -> GameSession:
	return GameSession.new(func() -> float: return 0.0)


func _cell(index: int) -> Vector2i:
	return WorldContract.farm_cells()[index]


func _count(counts: Dictionary, kind: GameRules.CropKind) -> int:
	return int(counts[GameRules.crop_key(kind)])


func _sleep(session: GameSession) -> GameRules.CommandCode:
	return session.sleep(BED)


func _farm_entry(session: GameSession, cell: Vector2i) -> Dictionary:
	for entry in session.snapshot()["farm"]:
		if entry["cell"] == cell:
			return entry
	return {}


func test_turnip_lifecycle_from_seed_to_payout() -> void:
	var session := _rainy()
	var cell := _cell(0)

	assert_int(session.hoe(cell)).is_equal(GameRules.CommandCode.SOIL_TILLED)
	assert_bool(bool(_farm_entry(session, cell)["tilled"])).is_true()

	assert_int(session.plant(cell)).is_equal(GameRules.CommandCode.CROP_PLANTED)
	var snapshot := session.snapshot()
	assert_int(_count(snapshot["seeds"], GameRules.CropKind.TURNIP)).is_equal(2)
	assert_int(_count(snapshot["seeds"], GameRules.CropKind.PUMPKIN)).is_equal(0)
	var crop: Dictionary = _farm_entry(session, cell)["crop"]
	assert_str(crop["kind"]).is_equal("turnip")

	assert_int(session.water(cell)).is_equal(GameRules.CommandCode.CROP_WATERED)
	assert_int(session.snapshot()["stamina"]).is_equal(20 - 3 - 1 - 2)

	# Rain waters the crop each night; turnips mature after 3 growth nights.
	for expected_growth in [1, 2, 3]:
		assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
		assert_int(session.acknowledge_morning_summary()).is_equal(GameRules.CommandCode.DAY_STARTED)
		crop = _farm_entry(session, cell)["crop"]
		assert_int(int(crop["growth"])).is_equal(expected_growth)

	assert_int(session.harvest(cell)).is_equal(GameRules.CommandCode.CROP_HARVESTED)
	assert_int(_count(session.snapshot()["harvested"], GameRules.CropKind.TURNIP)).is_equal(1)
	assert_that(_farm_entry(session, cell)["crop"]).is_null()

	assert_int(session.deposit_crop(GameRules.CropKind.TURNIP, 1, SHIPPING)).is_equal(
		GameRules.CommandCode.CROP_DEPOSITED
	)
	snapshot = session.snapshot()
	assert_int(_count(snapshot["harvested"], GameRules.CropKind.TURNIP)).is_equal(0)
	assert_int(_count(snapshot["pending_shipment"], GameRules.CropKind.TURNIP)).is_equal(1)

	# Sleeping settles the bin once: 150 + 35 = 185.
	assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
	snapshot = session.snapshot()
	assert_int(int(snapshot["money"])).is_equal(185)
	assert_int(_count(snapshot["shipped"], GameRules.CropKind.TURNIP)).is_equal(1)
	assert_int(_count(snapshot["pending_shipment"], GameRules.CropKind.TURNIP)).is_equal(0)
	var summary: Dictionary = snapshot["pending_morning_summary"]
	assert_int(int(summary["shipping_income"])).is_equal(35)


func test_sunny_night_without_watering_does_not_grow() -> void:
	var session := _sunny()
	var cell := _cell(0)
	session.hoe(cell)
	session.plant(cell)
	assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
	var crop: Dictionary = _farm_entry(session, cell)["crop"]
	assert_int(int(crop["growth"])).is_equal(0)
	assert_bool(bool(crop["watered_today"])).is_false()


func test_stamina_exhaustion_and_overnight_recovery() -> void:
	var session := _sunny()
	for index in 6:
		assert_int(session.hoe(_cell(index))).is_equal(GameRules.CommandCode.SOIL_TILLED)
	assert_int(session.snapshot()["stamina"]).is_equal(2)
	assert_int(session.hoe(_cell(6))).is_equal(GameRules.CommandCode.INSUFFICIENT_STAMINA)
	assert_bool(bool(_farm_entry(session, _cell(6))["tilled"])).is_false()

	assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
	session.acknowledge_morning_summary()
	var snapshot := session.snapshot()
	assert_int(int(snapshot["stamina"])).is_equal(GameRules.MAX_STAMINA)
	assert_int(int(snapshot["time_minutes"])).is_equal(GameRules.DAY_START_MINUTES)
	# The seventh cell is tillable again after rest.
	assert_int(session.hoe(_cell(6))).is_equal(GameRules.CommandCode.SOIL_TILLED)


func test_action_budget_cutoff_boundary() -> void:
	# Hoe costs 30 minutes; the cutoff is 1320 and ending exactly there is legal.
	var ok: Dictionary = GameRules.evaluate_action_budget(1290, 20, GameRules.FarmingAction.HOE)
	assert_bool(bool(ok["ok"])).is_true()
	assert_int(int(ok["time_minutes"])).is_equal(1320)
	var late: Dictionary = GameRules.evaluate_action_budget(1291, 20, GameRules.FarmingAction.HOE)
	assert_bool(bool(late["ok"])).is_false()
	assert_int(int(late["code"])).is_equal(GameRules.CommandCode.ACTION_TOO_LATE)
	var tired: Dictionary = GameRules.evaluate_action_budget(360, 2, GameRules.FarmingAction.HOE)
	assert_bool(bool(tired["ok"])).is_false()
	assert_int(int(tired["code"])).is_equal(GameRules.CommandCode.INSUFFICIENT_STAMINA)


func test_shop_purchase_and_guards() -> void:
	var session := _sunny()
	assert_int(
		session.buy_seeds(GameRules.CropKind.TURNIP, 2, SHOP)
	).is_equal(GameRules.CommandCode.SEEDS_PURCHASED)
	var snapshot := session.snapshot()
	assert_int(int(snapshot["money"])).is_equal(150 - 2 * 20)
	assert_int(_count(snapshot["seeds"], GameRules.CropKind.TURNIP)).is_equal(5)

	assert_int(
		session.buy_seeds(GameRules.CropKind.TURNIP, 1, Vector2i(6, 9))
	).is_equal(GameRules.CommandCode.NOT_AT_SHOP)
	assert_int(
		session.buy_seeds(GameRules.CropKind.TURNIP, 0, SHOP)
	).is_equal(GameRules.CommandCode.INVALID_QUANTITY)
	assert_int(
		session.buy_seeds(GameRules.CropKind.PUMPKIN, 3, SHOP)
	).is_equal(GameRules.CommandCode.INSUFFICIENT_FUNDS)
	assert_int(int(session.snapshot()["money"])).is_equal(110)


func test_social_daily_limits_and_points() -> void:
	var session := _rainy()
	var cell := _cell(0)
	var keeper_cell := WorldContract.villager_cell(VillagerRules.VillagerId.SHOPKEEPER)

	var talk: Dictionary = session.talk_to(VillagerRules.VillagerId.SHOPKEEPER, keeper_cell)
	assert_int(int(talk["code"])).is_equal(GameRules.CommandCode.VILLAGER_TALKED)
	assert_int(int(talk["points_gained"])).is_equal(VillagerRules.TALK_POINTS)
	# Second talk the same day still succeeds but grants nothing.
	talk = session.talk_to(VillagerRules.VillagerId.SHOPKEEPER, keeper_cell)
	assert_int(int(talk["points_gained"])).is_equal(0)

	# Gifting needs a harvested crop and the villager's exact cell.
	assert_int(
		session.gift_crop(VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.TURNIP, keeper_cell)["code"]
	).is_equal(GameRules.CommandCode.INSUFFICIENT_CROPS)
	assert_int(
		session.talk_to(VillagerRules.VillagerId.FARMER, keeper_cell)["code"]
	).is_equal(GameRules.CommandCode.NOT_AT_VILLAGER)

	session.hoe(cell)
	session.plant(cell)
	# Day 1 weather is fixed sunny; water now so nights 1-3 all advance growth.
	assert_int(session.water(cell)).is_equal(GameRules.CommandCode.CROP_WATERED)
	for _night in 3:
		assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
		assert_int(session.acknowledge_morning_summary()).is_equal(GameRules.CommandCode.DAY_STARTED)
	assert_int(session.harvest(cell)).is_equal(GameRules.CommandCode.CROP_HARVESTED)
	# Turnip is the resident's favourite but not the shopkeeper's: +3, not +5.
	var gift: Dictionary = session.gift_crop(
		VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.TURNIP, keeper_cell
	)
	assert_int(int(gift["code"])).is_equal(GameRules.CommandCode.CROP_GIFTED)
	assert_int(int(gift["points_gained"])).is_equal(VillagerRules.GIFT_POINTS)
	assert_str(gift["gift_reaction"]).is_equal("normal")
	assert_int(
		session.gift_crop(VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.TURNIP, keeper_cell)["code"]
	).is_equal(GameRules.CommandCode.GIFT_ALREADY_GIVEN)

	# Sleep resets the daily talk/gift flags (after acknowledging the summary).
	assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)
	session.acknowledge_morning_summary()
	talk = session.talk_to(VillagerRules.VillagerId.SHOPKEEPER, keeper_cell)
	assert_int(int(talk["points_gained"])).is_equal(VillagerRules.TALK_POINTS)


func test_state_round_trip_preserves_progress() -> void:
	var session := _sunny()
	session.hoe(_cell(0))
	session.plant(_cell(0))
	session.talk_to(VillagerRules.VillagerId.SHOPKEEPER, WorldContract.villager_cell(0))
	assert_int(_sleep(session)).is_equal(GameRules.CommandCode.DAY_ADVANCED)

	var restored := GameSession.new(func() -> float: return 0.5)
	assert_bool(restored.restore_state(session.state())).is_true()
	assert_dict(restored.snapshot()).is_equal(session.snapshot())
