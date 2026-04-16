extends AutoworkTest

class TestActionDynamic extends BlaziumGoapAction:
	var use_dynamic = false
	func _init():
		set_name("DynamicAction")
		cost = 1
	
	func _prepare_action():
		if use_dynamic:
			effects = {"dynamic_goal_met": true}
			preconditions = {"has_money": true}
		else:
			effects = {}
			preconditions = {}

	func _perform(_delta: float) -> bool:
		return true

class TestGoalDynamicPriority extends BlaziumGoapGoal:
	var base_weight = 1
	var boost = false
	func _init():
		set_name("DynamicGoal")
		desired_state = {"dynamic_goal_met": true}

	func _get_priority() -> int:
		if boost:
			return base_weight + 100
		return base_weight

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

func test_dynamic_goal_priority_boost():
	var action = TestActionDynamic.new()
	action.use_dynamic = true
	var action_idle = BlaziumGoapAction.new()
	action_idle.name = "Idle"
	action_idle.effects = {"idle": true}
	
	var goal_dynamic = TestGoalDynamicPriority.new()
	goal_dynamic.base_weight = 1
	
	var goal_static = BlaziumGoapGoal.new()
	goal_static.name = "StaticGoal"
	goal_static.priority = 50
	goal_static.desired_state = {"idle": true}
	
	action_container.add_child(action)
	action_container.add_child(action_idle)
	goal_container.add_child(goal_dynamic)
	goal_container.add_child(goal_static)
	
	agent.init(actor)
	agent.get_world_state().set_state("has_money", true)
	
	# With boost = false, priority is 1 vs 50, Agent picks StaticGoal
	goal_dynamic.boost = false
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_eq(agent.get("current_goal"), goal_static, "Static Goal should priority win natively")
	
	# With boost = true, priority is 101 vs 50, Agent picks DynamicGoal!
	goal_dynamic.boost = true
	agent.notification(Node.NOTIFICATION_PROCESS)
	assert_eq(agent.get("current_goal"), goal_dynamic, "Dynamic Goal should overtake after evaluation dynamically!")

	# Check dynamic action bindings mapped effectively
	# The plan should use TestActionDynamic
	var plan = agent.get("current_plan")
	assert_true(plan.size() > 0, "Plan should be generated mapping to dynamic requirements natively")
