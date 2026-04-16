extends AutoworkTest

class TestActionCheapestA extends BlaziumGoapAction:
	func _init():
		set_name("CheatA")
		cost = 10
		effects = {"money": true}

class TestActionCheapestA1 extends BlaziumGoapAction:
	func _init():
		set_name("CheatA1")
		cost = 1
		effects = {"silver": true}

class TestActionCheapestA2 extends BlaziumGoapAction:
	func _init():
		set_name("CheatA2")
		cost = 1
		effects = {"gold": true}
		preconditions = {"silver": true}

class TestActionCheapestA3 extends BlaziumGoapAction:
	func _init():
		set_name("CheatA3")
		cost = 1
		effects = {"money": true}
		preconditions = {"gold": true}

class TestGoalCheap extends BlaziumGoapGoal:
	func _init():
		set_name("RichGoal")
		desired_state = {"money": true}

class TestActionInvalid extends BlaziumGoapAction:
	var valid_state = true
	func _init():
		set_name("InvalidatedAction")
		cost = 1
		effects = {"impossible": true}
	func _is_valid() -> bool:
		return valid_state
	func _perform(_d: float) -> bool:
		return true

class TestGoalImpossible extends BlaziumGoapGoal:
	var failed = false
	func _init():
		set_name("ImpossibleGoal")
		desired_state = {"impossible": true}
	func _on_goal_failed():
		failed = true

var agent: BlaziumGoapAgent
var actor: Node
var goal_container: Node
var action_container: Node

func _before_each():
	actor = Node.new()
	actor.name = "Actor"
	Engine.get_main_loop().root.add_child(actor)

	agent = BlaziumGoapAgent.new()
	agent.name = "Agent"
	actor.add_child(agent)
	
	goal_container = Node.new()
	goal_container.name = "Goals"
	agent.add_child(goal_container)
	
	action_container = Node.new()
	action_container.name = "Actions"
	agent.add_child(action_container)
	
	agent.goals_node = NodePath("Goals")
	agent.actions_node = NodePath("Actions")

func _after_each():
	if actor:
		actor.queue_free()

func test_action_planner_chooses_cheapest_plan():
	# Agent has two paths:
	# CheatA (cost 10) -> Money
	# CheatA1 (1) -> CheatA2 (1) -> CheatA3 (1) -> Money (Total Cost: 3)
	# The A* backward planner must choose the 3-chain path over the single action path natively!
	
	var a = TestActionCheapestA.new()
	var a1 = TestActionCheapestA1.new()
	var a2 = TestActionCheapestA2.new()
	var a3 = TestActionCheapestA3.new()
	var g = TestGoalCheap.new()
	
	action_container.add_child(a)
	action_container.add_child(a1)
	action_container.add_child(a2)
	action_container.add_child(a3)
	goal_container.add_child(g)
	
	agent.init(actor)
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	var plan = agent.get("current_plan")
	assert_not_null(plan)
	assert_eq(plan.size(), 4, "A* Planner must choose the 3 step chain (+1 goal terminal node = 4) since its total cost natively is 3 vs 10!")
	if plan.size() == 4:
		assert_eq(plan[0], a1, "First node should be a1")
		assert_eq(plan[1], a2, "Second node should be a2")
		assert_eq(plan[2], a3, "Third node should be a3")

func test_impossible_goal_fails_gracefully():
	var a = TestActionInvalid.new()
	a.valid_state = false
	var g = TestGoalImpossible.new()
	
	action_container.add_child(a)
	goal_container.add_child(g)
	
	agent.init(actor)
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	# Since action is not valid, no plan is possible! Goal should trigger _on_goal_failed
	assert_true(g.failed, "Impossible goal must securely fire failure bounds through agent recursively to notify logic")
	
	var plan = agent.get("current_plan")
	assert_eq(plan.size(), 0, "No plan should have successfully mapped.")

func test_action_invalidation_mid_execution():
	var a = TestActionInvalid.new()
	a.valid_state = true
	var g = TestGoalImpossible.new()
	
	action_container.add_child(a)
	goal_container.add_child(g)
	
	agent.init(actor)
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	var plan = agent.get("current_plan")
	assert_eq(plan.size(), 2, "Path is initially verified safely.")
	
	# Corrupt the action dynamically! Ensure agent recovers safely when plan iterates!
	a.valid_state = false
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	# The effects of `a` were verified and missing because `a` perform was faked and didn't securely map state variables!
	# The agent attempts a replan. Since valid_state is false, replan fails.
	# The goal fails natively.
	assert_true(g.failed, "Goal triggers failed safely because effect loop didn't actually fulfill the goal requirements securely!")
