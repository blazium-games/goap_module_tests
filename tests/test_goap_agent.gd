extends AutoworkTest

class TestActionGatherWood extends BlaziumGoapAction:
	func _init():
		set_name("GatherWood")
		cost = 1
		effects = {"has_wood": true}
	func _perform(_delta: float) -> bool:
		return true

class TestActionBuildCampfire extends BlaziumGoapAction:
	func _init():
		set_name("BuildCampfire")
		cost = 2
		preconditions = {"has_wood": true}
		effects = {"has_campfire": true}
	func _perform(_delta: float) -> bool:
		return true

class TestGoalSurvive extends BlaziumGoapGoal:
	var achieved := false
	func _init():
		set_name("SurviveGoal")
		priority = 10
		desired_state = {"has_campfire": true}
	func _on_goal_achieved():
		achieved = true

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

func test_agent_solves_simple_path():
	var action1 = TestActionGatherWood.new()
	var action2 = TestActionBuildCampfire.new()
	action_container.add_child(action1)
	action_container.add_child(action2)
	
	var goal = TestGoalSurvive.new()
	goal_container.add_child(goal)
	
	agent.init(actor)
	
	# Validate state before process loops
	assert_false(goal.achieved, "Goal should not be achieved initially.")
	assert_false(agent.get_world_state().get_state("has_wood", false), "Should not have wood")
	assert_false(agent.get_world_state().get_state("has_campfire", false), "Should not have campfire")
	
	# Simulate Engine Ticks
	agent.notification(Node.NOTIFICATION_PROCESS) # Initializes goal/plan
	
	var current_plan = agent.get("current_plan")
	assert_not_null(current_plan)
	
	# Tick action 1 (Gather Wood)
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_true(agent.get_world_state().get_state("has_wood", false), "Action 1 should have applied effect 'has_wood'=true")
	
	# Tick action 2 (Build Campfire)
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_true(agent.get_world_state().get_state("has_campfire", false), "Action 2 should have applied effect 'has_campfire'=true")
	
	# Final resolution tick
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_true(goal.achieved, "Goal should officially signal _on_goal_achieved dynamically!")

func test_world_state_satisfaction_evaluations():
	var valid: bool
	
	# Boolean validations
	valid = BlaziumGoapWorldState.is_satisfied(true, true)
	assert_true(valid, "True matches True")
	valid = BlaziumGoapWorldState.is_satisfied(null, true)
	assert_false(valid, "Null does not match True implicitly")
	
	# Number validations
	valid = BlaziumGoapWorldState.is_satisfied(10.0, 10.0)
	assert_true(valid, "Floats should match securely")
	
	valid = BlaziumGoapWorldState.is_satisfied(5, 5.0)
	assert_true(valid, "Mixed Integer and Float bindings natively eval internally through dictionary")

	# Target false boolean matching
	valid = BlaziumGoapWorldState.is_satisfied(false, false)
	assert_true(valid, "False matches false")
