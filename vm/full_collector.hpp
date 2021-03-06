namespace factor
{

struct full_policy {
	factor_vm *parent;
	zone *tenured;

	full_policy(factor_vm *parent_) : parent(parent_), tenured(parent->data->tenured) {}

	bool should_copy_p(object *untagged)
	{
		return !tenured->contains_p(untagged);
	}
};

struct full_collector : copying_collector<tenured_space,full_policy> {
	bool trace_contexts_p;

	full_collector(factor_vm *parent_);
	void mark_active_blocks();
	void mark_object_code_block(object *object);
	void trace_callbacks();
	void trace_literal_references(code_block *compiled);
	void mark_code_block(code_block *compiled);
	void cheneys_algorithm();
};

}
