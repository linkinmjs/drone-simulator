class_name TutorialSequencer
extends Node
## Runs the lessons of the flight instructor in order. The lessons are its TutorialStep
## children. After a lesson is completed the next one starts by itself after its
## `success_delay`, or right away with `confirm()`.


signal lesson_started(index: int)
signal lesson_succeeded(index: int)
signal lesson_skipped(index: int)
signal tutorial_finished

enum State {IDLE, RUNNING, SUCCESS, FINISHED}

var steps: Array[TutorialStep] = []
var current_index := -1
var state := State.IDLE

var _success_timer: Timer = null


func setup(level: TutorialLevel) -> void:
	_success_timer = Timer.new()
	_success_timer.one_shot = true
	add_child(_success_timer)
	var _discard := _success_timer.timeout.connect(advance)
	steps.clear()
	for child in get_children():
		if child is TutorialStep:
			var step := child as TutorialStep
			steps.append(step)
			step.setup(level)
			_discard = step.completed.connect(_on_step_completed.bind(step))


func get_current_step() -> TutorialStep:
	if current_index < 0 or current_index >= steps.size():
		return null
	return steps[current_index]


func is_running() -> bool:
	return state == State.RUNNING


func start_at(index: int) -> void:
	stop_current()
	if steps.is_empty():
		return
	current_index = clampi(index, 0, steps.size() - 1)
	state = State.RUNNING
	lesson_started.emit(current_index)
	steps[current_index].start()


func stop_current() -> void:
	if _success_timer:
		_success_timer.stop()
	var step := get_current_step()
	if step and state != State.IDLE and state != State.FINISHED:
		step.stop()
	state = State.IDLE


func restart_current() -> void:
	if current_index >= 0:
		start_at(current_index)


func skip_current() -> void:
	if state != State.RUNNING and state != State.SUCCESS:
		return
	if state == State.RUNNING:
		lesson_skipped.emit(current_index)
	advance()


## Moves on right away when the current lesson is already completed.
func confirm() -> void:
	if state == State.SUCCESS:
		advance()


func advance() -> void:
	var next := current_index + 1
	if next >= steps.size():
		stop_current()
		state = State.FINISHED
		tutorial_finished.emit()
	else:
		start_at(next)


func on_drone_respawned() -> void:
	var step := get_current_step()
	if state == State.RUNNING and step:
		step.restart()


func _on_step_completed(step: TutorialStep) -> void:
	if step != get_current_step() or state != State.RUNNING:
		return
	state = State.SUCCESS
	lesson_succeeded.emit(current_index)
	_success_timer.start(maxf(step.success_delay, 0.05))
