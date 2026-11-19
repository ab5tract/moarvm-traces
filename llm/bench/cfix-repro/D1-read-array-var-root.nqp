# D1: read_array_var does not root `result` across MVM_serialization_read_ref.
#
# src/6model/serialization.c:1805-1823 allocates a BOOTArray (`result`),
# then for each element calls MVM_serialization_read_ref (which can demand
# objects of other SCs) and binds the element into `result`, with no MVMROOT.
#
# NOT A PROGRAM: no deterministic reproducer exists on this machine; the
# finding is classified by argument in cfix-baseline.md ("D1"). In short:
#   - every path that reaches read_array_var runs with tc->allocate_in_gen2
#     > 0 (MVM_serialization_deserialize, serialization.c:3202-3273;
#     MVM_serialization_demand_object/_stable/_code, 2872-2885, 2929-2942,
#     2966-2978): `result` is allocated in gen2 and gen2 objects never move,
#     and read_ref's own allocations go to gen2, so this thread cannot start
#     a nursery collection from the allocator. A collection cannot MOVE it.
#   - but read_ref -> read_obj_ref -> MVM_sc_get_object ->
#     MVM_serialization_demand_object locks the SC's reentrant mutex, and
#     MVM_reentrantmutex_lock marks the thread blocked around uv_mutex_lock
#     (ReentrantMutex.c:145-149) when it does not already hold it (an object
#     of another SC). While blocked, another thread may run a collection
#     with this thread's work stolen, and a full collection frees unmarked
#     gen2 objects of every thread it collects (orchestrate.c:217-223):
#     `result`, referenced from nothing but a C local, would be freed, and
#     the next bind_pos writes into freed memory.
# What would show it: a multi-threaded program that lazily deserializes,
# from a precompiled SC, an object whose attribute is a BOOTArray holding
# references into a second SC not yet deserialized, while another thread
# allocates enough to force full collections; under MVM_GC_DEBUG or ASAN.
say("D1: not a runnable reproducer; see the header and cfix-baseline.md");
