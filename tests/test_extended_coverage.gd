extends AutoworkTest




class TestExitGoal extends BlaziumGoapGoal:
	var entered = false
	var exited = false
	var prepared = false
	var performed_count = 0
	func _init():
		set_name("ExitCoverageGoal")
		desired_state = {"coverage": true}
	func _enter(): entered = true
	func _exit(): exited = true
	func _prepare(): prepared = true
	func _perform(_delta: float): 
		performed_count += 1

class TestActionComplete extends BlaziumGoapAction:
	var entered = false
	var exited = false
	var prepped = false
	func _init():
		set_name("CoverageAction")
		cost = 10
		effects = {"coverage": true}
	func _enter(): entered = true
	func _exit(): exited = true
	func _prepare_action(): prepped = true
	func _perform(_delta: float) -> bool:
		return true

var agent: BlaziumGoapAgent
var actor: Node
var runner: Node
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

func test_world_state_dictionary_clear_erase():
	var state = BlaziumGoapWorldState.new()
	state.set_state("a", 1)
	state.set_state("b", 2)
	assert_eq(state.get("state").size(), 2)
	
	state.erase_state("a")
	assert_eq(state.get("state").size(), 1)
	assert_null(state.get_state("a"))
	
	state.clear_state()
	assert_eq(state.get("state").size(), 0)

func test_action_and_goal_gdvirtual_execution():
	var g = TestExitGoal.new()
	var a = TestActionComplete.new()
	
	action_container.add_child(a)
	goal_container.add_child(g)
	
	agent.init(actor)
	
	# Empty desired state = empty plan = fallback to achieve goal if goal is only item cleanly!
	# But actually if goal has no desired_state, plan size is 1 natively.
	
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	assert_true(g.entered)
	assert_true(g.prepared)
	
	# Run a tick explicitly
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_true(g.performed_count >= 1, "Goal Perform explicitly executed natively.")
	
	# Since plan finishes instantly without needs, goal exits safely.
	assert_true(g.exited, "Goal completed and exited safely natively.")

func test_debugger_triggers_mechanically():
	# Validate debug bindings
	agent.set_debug_enabled(true)
	
	var a = BlaziumGoapAction.new()
	a.name = "DebugAction"
	action_container.add_child(a)
	
	agent.init(actor)
	
	assert_true(agent.debug_enabled, "Agent debug enabled properly.")

func test_action_effects_wrapper():
	var a = BlaziumGoapAction.new()
	a.effects = {"val": true}
	var state = BlaziumGoapWorldState.new()
	a.init(actor, state)
	
	a.apply_effects()
	assert_true(state.get_state("val", false), "Effects applied cleanly natively.")

func test_goal_invalidated_mid_tick():
	var g = BlaziumGoapGoal.new()
	g.name = "TestingGoal"
	g.default_valid_state = true
	g.priority = 100
	g.desired_state = {"a": true}
	
	var a = BlaziumGoapAction.new()
	a.effects = {"a": true}
	a.name = "Action"
	
	action_container.add_child(a)
	goal_container.add_child(g)
	agent.init(actor)
	
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_eq(agent.get("current_goal"), g)
	
	g.default_valid_state = false
	agent.notification(Node.NOTIFICATION_PROCESS)
	
	assert_null(agent.get("current_goal"), "Goal securely purged and zeroed natively!")

func test_planner_null_goal():
	var planner = BlaziumGoapActionPlanner.new()
	var out = planner.get_plan(null, {})
	assert_eq(out.size(), 0, "No exceptions natively on NULL planner goal")
