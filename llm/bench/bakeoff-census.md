# Bake-off census: the five internal hash table kinds (2026-11-03)

Static read of every creation site of `MVMStrHashTable`, `MVMUniHashTable`,
`MVMFixKeyHashTable`, `MVMIndexHashTable` and `MVMPtrHashTable` in the C tree
(`src/`, excluding the table implementations and `src/zig/`), on branch
`zig-hash-bakeoff` at 09bf93ed7. Campaign spec:
`traces/llm/specs/2026-11-03-zig-hash-layout-bakeoff-design.md`, section 9.
No code was changed.

## Method

1. `grep -rn -E 'MVM_(str|uni|fixkey|index|ptr)_hash_build\b' src/` minus the
   implementations: **21 build call sites** (str 8, uni 2, fixkey 8, index 2,
   ptr 1). Every one has a row below.
2. Because uni and ptr tables (and str tables via `shallow_copy`) are valid
   when zero-filled and need no build call, every field or variable of the
   five types was also enumerated (`grep -rn -E '\bMVM(Str|Uni|FixKey|Index|Ptr)HashTable\b'`),
   and every `*_shallow_copy` call. That adds **5 creation sites with no build
   call** (marked "implicit" below): str 1, uni 2, index 1, ptr 1.
3. Each site's operation mix comes from every use of the table it creates
   (`grep -o 'MVM_<kind>_hash_[a-z_]*'` per file, then reading the callers).

Total: **26 creation sites** (str 9, uni 4, fixkey 8, index 3, ptr 2).

Column key. Ops: I insert (new key, `insert`/`insert_nocheck`), F fetch
(`fetch`/`fetch_nocheck`, hit and miss), L lvalue-fetch (get-or-insert),
D delete, It iterate (`first`/`next`/`current`, `foreach`), C shallow-copy,
X demolish. Key set: **sealable** (complete at one moment, never grows after),
**grows** (grows with the program, no deletes), **churns** (grows and
shrinks, deletes), **refilled** (cleared and refilled). Lifetime: instance
(process), thread, object (GC-managed owner), static frame, snapshot.

## str (`MVMStrHashTable`, key `MVMString *` with cached hash code)

| # | Site | Owner | Entry type | Size hint |
|---|---|---|---|---|
| s1 | `src/moar.c:203` | `MVMInstance.sc_weakhash` | `MVMSerializationContextWeakHashEntry` (key + `scb` pointer) | 0 |
| s2 | `src/core/bytecode.c:777` | `MVMStaticFrameInstrumentation.debug_locals` (in `MVMStaticFrameBody`) | `MVMStaticFrameDebugLocal` (key + `local_idx` u16) | `num_debug_locals` |
| s3 | `src/6model/reprs/HashAttrStore.c:33` (`copy_to`) | `MVMHashAttrStoreBody.hashtable` | `MVMHashEntry` (key + `MVMObject *value`) | `MVM_str_hash_count(src)` |
| s4 | `src/6model/reprs/HashAttrStore.c:96` (`bind_attribute`) | `MVMHashAttrStoreBody.hashtable` | `MVMHashEntry` | 0 |
| s5 | `src/6model/reprs/MVMHash.c:115` (`bind_key`) | `MVMHashBody.hashtable` | `MVMHashEntry` | 0 |
| s6 | `src/6model/reprs/MVMHash.c:191` (`deserialize`) | `MVMHashBody.hashtable` | `MVMHashEntry` | `elems` read from the stream |
| s7 | `src/core/nativecall_libffi.c:85` | `MVMThreadContext.native_callback_cache` | `MVMNativeCallbackCacheHead` (key + list head) | 0 |
| s8 | `src/core/nativecall_dyncall.c:91` | `MVMThreadContext.native_callback_cache` (same field, other backend) | `MVMNativeCallbackCacheHead` | 0 |
| s9 | implicit: `src/6model/reprs/MVMHash.c:40` (`copy_to`, `MVM_str_hash_shallow_copy`) | `MVMHashBody.hashtable` of the clone | `MVMHashEntry` | none (verbatim copy of the source block) |

| # | Ops | Key set | Lifetime | Justification (from the code) |
|---|---|---|---|---|
| s1 | L, F, D, It, X | churns | instance | `MVM_sc_create` (`sc.c:22`) lvalue-fetches by handle; `MVM_sc_find_by_handle` (`sc.c:380`) fetches; SCRef `gc_free` (`SCRef.c:123`) deletes; `roots.c:105` iterates every GC to mark keys; one entry per serialization context, so it grows with modules loaded and loses entries as SCs die. |
| s2 | I, F, It, X (with the static frame) | sealable | static frame | Built only with the debug server on; `bytecode.c:782` inserts all `num_debug_locals` names in one loop at frame deserialization; afterwards only `debugserver.c:2232` fetches and `:2194`, `:2256`, `MVMStaticFrame.c:163` (GC mark) iterate. |
| s3 | I (bulk), F, L, It, X | grows | object | Clone of a HashAttrStore: presized to the source count, then every source entry inserted in one loop (a bulk load from another table's iteration); afterwards behaves like s4. |
| s4 | L, F, It, X | grows | object | `bind_attribute` lvalue-fetches (new attribute or overwrite), `get_attribute`/`is_attribute_initialized` fetch, `gc_mark` iterates; no delete path exists in the REPR. Attribute names per class, so small. |
| s5 | L, F, D, It, C (as source), X | churns | object | The general `nqp::hash` table: built lazily on the first `bind_key` (no REPR `initialize`); `at_key`/`exists_key` fetch (hit and miss), `delete_key` deletes, `MVMHash_gc_mark` and `serialize` iterate, `MVMIter` iterates with delete-at-current (`MVMIter.c:119`, `MVM_str_hash_iterator_target_deleted`), `args.c:149` iterates to flatten named args, `copy_to` shallow-copies. Every runtime MVMHash (slurpy nameds, `nqp::hash`, Raku Map/Hash storage) reaches its table here. |
| s6 | I (bulk), then as s5 | sealable at load, then churns | object | `deserialize` presizes to `elems` and inserts exactly `elems` keys in one loop: the key set is complete at the end of the loop; afterwards the object is an ordinary MVMHash (s5 ops). Spec 5.3 already uses this point for the override's seal. |
| s7 | L, It, X | grows | thread | `unmarshal_callback` lvalue-fetches by the callback's static-frame `cuuid`, then walks a linked list in the entry; `roots.c:190` iterates for GC; never deletes; entries = distinct callback frames seen by this thread (tiny). |
| s8 | L, It, X | grows | thread | Same as s7 for the dyncall backend; only one of s7/s8 is compiled in. |
| s9 | C, then as s5 | as source | object | `MVMHash` clone (`nqp::clone`) copies the block verbatim, then iterates it for write barriers; the clone then behaves like s5. Spec section 3 already records that every new tier's block must survive this copy. |

## uni (`MVMUniHashTable`, key `const char *` in static storage, value u32)

| # | Site | Owner | Entry type | Size hint |
|---|---|---|---|---|
| u1 | `src/strings/unicode_ops.c:915` | `MVMInstance.property_codes_by_names_aliases` | `MVMUniHashEntry` (key, hash_val, value) | `num_unicode_property_keypairs` (4380) |
| u2 | `src/strings/unicode_ops.c:930` | `MVMInstance.property_codes_by_seq_names` | `MVMUniHashEntry` | `num_unicode_seq_keypairs` (3680) |
| u3 | implicit: `src/strings/unicode_db.c:129559` (first `MVM_uni_hash_insert` into a zeroed table, which builds at `uni_hash_table.c:281` with 0) | `MVMInstance.codepoints_by_name` | `MVMUniHashEntry` | 0 (fills to about 64645 codepoint names + 481 aliases) |
| u4 | implicit: `src/strings/unicode_ops.c:955` (`MVM_calloc` of `MVM_NUM_PROPERTY_CODES` = 115 zeroed tables, comment "zeroes is a valid start state") | `MVMInstance.unicode_property_values_hashes[]` | `MVMUniHashEntry` | 0 each (5164 values spread over 115 tables, plus 16 yes/no names for each table left empty) |

| # | Ops | Key set | Lifetime | Justification (from the code) |
|---|---|---|---|---|
| u1 | I (bulk), F | sealable | instance | `generate_property_codes_by_names_aliases` inserts the whole static `unicode_property_keypairs` array once under a mutex, lazily on the first `MVM_unicode_name_to_property_code`; afterwards only `MVM_uni_hash_fetch` (`:947`), hit or miss (a miss returns 0). Never iterated, never deleted. |
| u2 | I (bulk), F | sealable | instance | Same shape: whole `uni_seq_pairs` array inserted once (`:933`), then only fetched in `MVM_unicode_string_from_name` (`:1049`). |
| u3 | I (bulk), F | sealable | instance | `generate_codepoints_by_name` inserts every named codepoint and alias in one pass, lazily on the first `MVM_unicode_lookup_by_name` (`unicode_ops.c:705`); afterwards only fetch (`:708`), and a miss falls through to prefix parsing (`CJK UNIFIED IDEOGRAPH-` etc.), so misses are a real path. The largest internal table. |
| u4 | I (bulk), F | sealable | instance | `MVM_unicode_init` (called once from `moar.c:226`) inserts every property value, then fills empty tables with yes/no names; afterwards only `unicode_cname_to_property_value_code` fetches (`:990`). Demolished at `moar.c:789`. |

## fixkey (`MVMFixKeyHashTable`, key `MVMString *`, entries behind a pointer so they never move)

`MVM_fixkey_hash_build` takes an `entry_size`, not a size hint; every table
starts at the minimum size. The defining property (header comment,
`fixkey_hash_table.h:46-79`): the stored value must not move in memory,
because callers keep pointers to entries (and register their key fields as
permanent GC roots). There is no delete.

| # | Site | Owner | Entry type | Size hint |
|---|---|---|---|---|
| f1 | `src/moar.c:186` | `MVMInstance.compiler_hll_configs` | `MVMHLLConfig` | none (entry_size `sizeof(MVMHLLConfig)`) |
| f2 | `src/moar.c:187` | `MVMInstance.compilee_hll_configs` | `MVMHLLConfig` | none |
| f3 | `src/moar.c:191` | `MVMInstance.dll_registry` | `MVMDLLRegistry` (key, `DLLib *`, refcount) | none |
| f4 | `src/moar.c:195` | `MVMInstance.ext_registry` | `MVMExtRegistry` (key, `MVMDLLSym *`) | none |
| f5 | `src/moar.c:199` | `MVMInstance.extop_registry` | `MVMExtOpRegistry` (key, func, op info, spesh hook) | none |
| f6 | `src/moar.c:207` | `MVMInstance.loaded_compunits` | `MVMString *` (key only, a set) | none |
| f7 | `src/moar.c:210` | `MVMInstance.container_registry` | `MVMContainerConfigurer *` (entry_size 0: indirect to static storage) | none |
| f8 | `src/disp/syscall.c:1671` | `MVMInstance.syscalls` | `MVMDispSysCall *` (entry_size 0: static storage) | none |

| # | Ops | Key set | Lifetime | Justification (from the code) |
|---|---|---|---|---|
| f1 | L, F (via L), X | grows (tiny) | instance | `MVM_hll_get_config_for` (`hll.c:16`) lvalue-fetches, creating the config on first sight; called per compunit (`compunit.c:25`), per `hllboolfor` (`interp.c:5270`), from serialization (`serialization.c:2604`) and at spesh/JIT time (`facts.c:570`, `optimize.c:1010`, `jit/graph.c:2268`). One entry per HLL (nqp, Raku: a handful). |
| f2 | L, F (via L), X | grows (tiny) | instance | Same function, `hll.c:13`, when `hll_compilee_depth` is non-zero. |
| f3 | F, I, It (`foreach` at teardown), X | grows | instance | `MVM_dll_load` fetches then inserts (`dll.c:13`, `:37`); `MVM_dll_free` and `MVM_dll_find_symbol` fetch (`:57`, `:99`); `moar.c:748` `foreach` frees libs before demolish. "Free" clears `entry->lib`, never deletes the key. |
| f4 | F, I, X | grows | instance | `MVM_ext_load` fetches (`ext.c:19`), inserts on first load (`:37`); one entry per loaded extension. |
| f5 | F, I, X | grows | instance | Inserted per registered extension op (`ext.c:151`, after a fetch at `:64`); fetched by `MVM_ext_resolve_extop_record` (`:196`) at bytecode validation, and the result is cached in the record, so lookups are once per call site record. |
| f6 | F, I, X | grows | instance | `loadbytecode.c:124` fetches the filename, `:138` inserts after loading; one entry per loaded bytecode file; a set (entry is just the key). |
| f7 | I, F, X | sealable | instance | `MVM_6model_containers_setup` inserts exactly 3 static configurers (`containers.c:857-859`) at startup; afterwards only `MVM_6model_get_container_config` fetches (`interp.c:2877`, `serialization.c:2578`). |
| f8 | I, F, X | sealable | instance | `MVM_disp_syscall_setup` builds and inserts exactly 10 static syscalls in one function (`syscall.c:1671-1681`); afterwards only `MVM_disp_syscall_find` (`:1761`, called from `disp/boot.c:162`, once per dispatch recording, not per call). |

## index (`MVMIndexHashTable`, entry is a u32 index into an external `MVMString *` array)

| # | Site | Owner | Entry type | Size hint |
|---|---|---|---|---|
| i1 | `src/moar.c:182` | `MVMInstance.repr_hash` (keys in `repr_names[]`) | `MVMIndexHashEntry` (u32 index) | `MVM_REPR_CORE_COUNT` (47) |
| i2 | `src/core/bytecode.c:667` | `MVMStaticFrameBody.lexical_names` (keys in `lexical_names_list[]`) | `MVMIndexHashEntry` | `sf->body.num_lexicals` (only when more than 5; 5 or fewer lexicals leave the table unbuilt and lookups scan the list) |
| i3 | implicit: `src/6model/reprs/MVMStaticFrame.c:73` (`copy_to`, `MVM_index_hash_shallow_copy`) | `MVMStaticFrameBody.lexical_names` of the clone | `MVMIndexHashEntry` | none (verbatim copy; NULL stays NULL) |

| # | Ops | Key set | Lifetime | Justification (from the code) |
|---|---|---|---|---|
| i1 | I, F, X | grows (sealable in practice) | instance | `register_repr` inserts each core REPR at startup (`reprs.c:194`); `MVM_repr_register_dynamic_repr` fetches then may insert (`:205`); `MVM_repr_name_to_id` fetches (`:304`). Dynamic REPRs are rare, so the key set is the 47 core REPRs plus extensions. |
| i2 | I (bulk), F, C (as source), X | sealable | static frame | `bytecode.c:682` inserts every lexical name in one loop at frame deserialization, presized exactly; afterwards only `MVM_get_lexical_by_name` (`MVMStaticFrame.c:374`) fetches. Lookup by name walks outer frames (`frame.c:1318`, `:1370`), so each lookup is a run of misses ending in one hit. Never iterated (`lexical_names_list` is iterated instead), never deleted. One table per static frame with more than 5 lexicals: by count, the most numerous internal table kind. |
| i3 | C, F, X | sealable | static frame | Static-frame clone; same lookups as i2 afterwards. |

## ptr (`MVMPtrHashTable`, key `const void *`, value `uintptr_t`)

| # | Site | Owner | Entry type | Size hint |
|---|---|---|---|---|
| p1 | `src/moar.c:214` | `MVMInstance.object_ids` | `MVMPtrHashEntry` (key, value) | none (build only sets `table = NULL`) |
| p2 | implicit: `src/profiler/heapsnapshot.c:746` (`memset(&ss, 0, ...)` of a stack `MVMHeapSnapshotState`) | `MVMHeapSnapshotState.seen` | `MVMPtrHashEntry` | none |

| # | Ops | Key set | Lifetime | Justification (from the code) |
|---|---|---|---|---|
| p1 | I, F, fetch-and-delete, X | churns | instance | `MVM_gc_object_id` (`objectid.c:20`, `:28`) fetches or inserts for nursery objects asked for an id; the GC calls `fetch_and_delete` when such an object is promoted (`collect.c:259`) or dies (`collect.c:572`, `:608`). Entries live only while the object is in the nursery. |
| p2 | L, X | grows, then demolished | snapshot | `get_collectable_idx` and `get_frame_idx` (`heapsnapshot.c:254`, `:287`) lvalue-fetch every collectable and frame reached, assigning an index on first sight; demolished at the end of each snapshot (`:758`). One entry per live heap object: potentially millions, insert-if-absent heavy. |

## Notes outside the brief's columns

- **No spesh, JIT, NFG or serialization-internal tables.** `src/spesh`,
  `src/jit`, `src/strings/nfg.c` and `src/6model/serialization.c` create none
  of the five kinds; they only call registry lookups (f1, f7) or deserialize
  MVMHash (s6). Spesh and NFG use their own structures.
- **Zero-filled means empty** is load-bearing for uni (u3, u4: `calloc`
  comment "zeroes is a valid start state"), ptr (p1, p2), str (s5, s7: the
  table is checked with `MVM_str_hash_entry_size` and built lazily) and index
  (i2: unbuilt for 5 or fewer lexicals; `MVM_index_hash_built` checks).
- **Lvalue-fetch on an existing key must not grow the table.**
  `str_hash_table.c:464-468`: growth invalidates live iterators, so a full
  table first tries a plain fetch. Any candidate layout inherits this rule.
- **Delete at the current iterator position must not lose or repeat entries**
  (s5 through `MVMIter.c:119`). Robin Hood achieves it by iterating in
  reverse (`str_hash_table.c:96-100`), so backward-shift moves only entries
  already visited.

## Candidates this suggests

**Fixed-key (4.3) material** is the largest group, and almost none of it is
a str table. The load-once, read-forever sites are u1, u2, u3, u4 (all
inserted in one bulk pass from a static array, then only fetched, with real
miss paths in u1 and u3), i2/i3 (every lexical-name table: built in one
presized loop, then only fetched, misses dominating because lookup walks
outer frames), f7 and f8 (startup-only, 3 and 10 keys), s2 (debug locals,
debug server only) and s6 up to the end of `deserialize`. i1 is sealable in
practice. **Swiss (4.1) material** is the lookup-heavy and churning sites:
s5 (general MVMHash, fetch hit and miss plus deletes), s1 (deletes as SCs
die), p1 (insert and fetch-and-delete churn) and p2 (millions of
insert-if-absent probes, mostly misses-then-insert). **Array-ordered (4.2)
material** is the iterate-heavy sites: s5 under GC marking, serialization and
`MVMIter`; s1 (iterated every GC); s3 (a clone that rebuilds by iterating
the source); and s7/s8 (iterated each GC, rarely looked up). The small
grows-only registries (f1-f6) are too small and too cold to distinguish
layouts; their real constraint is pointer stability, which fixkey's
indirection provides independent of the layout.

**Operations sites depend on that the ladder does not measure:**

1. **Lvalue-fetch of an existing key (overwrite)**: s4, s5 (`bind_key` on a
   present key), s1, f1/f2, s7/s8, p2. The ladder's `insert` binds fresh keys
   only (`hash-bench.nqp:85`).
2. **Shallow copy (clone)**: s9 and i3. The block-copy cost scales with the
   block size, which differs per layout (Swiss's lower load factor, the
   array layout's two blocks).
3. **Delete at the current iterator position, then continue iterating**: s5
   via `MVMIter`. The ladder deletes by key outside any iteration.
4. **Fetch-and-delete** (p1): ptr only, outside the bake-off's str scope.
5. **Clone-by-reinsert** (s3: presize to N, insert N from another table's
   iteration) is a bulk load the ladder's bulk-load (insert N then seal)
   covers only for strategy 3.

## Proposed errata (for the user's ruling; the spec is unchanged)

- **E1 (candidate 4.2, correctness).** Swap-remove moves the last entry into
  the hole. If the array tier iterates front to back, a delete at the current
  iterator position (`MVMIter.c:119`, s5) moves a not-yet-visited entry into
  an already-visited slot and the iteration skips it. Proposed: section 4.2
  states that the array tier iterates from the last entry to the first (as
  Robin Hood does), so swap-remove only moves visited entries. Without this
  the strategy-2 spectest gate is the only thing that would catch it.
- **E2 (ladder op columns).** Add an `overwrite` cell (bind N present keys)
  and optionally `clone` (`nqp::clone` of a hash of size N) and
  `iterate_delete` (delete every key from inside a `for %h` loop) to
  `hash-bench.nqp`. `overwrite` is the commonest unmeasured operation among
  the sites (item 1 above); `iterate_delete` doubles as the E1 regression
  check. The user may prefer to leave clone out: only s9 and i3 depend on it.
- **E3 (scope note, not a candidate change).** The strongest fixed-key and
  lookup-miss material (u1-u4, i2) lives in the uni and index kinds, which
  section 4 does not cover (each candidate is a tier set in `str.zig`).
  The next campaign's assignment of internal tables to strategies needs
  those tiers ported to the uni and index kinds, or the census's best sites
  stay out of reach. Proposed: one sentence in section 4 or 8 saying so.
- **E4 (minor wording).** Section 5.3 says the override applies at "MVMHash
  initialize and deserialize"; MVMHash has no REPR `initialize`
  (`MVMHash.c:276`, `NULL`) and builds lazily in `bind_key` (`MVMHash.c:115`),
  as section 3 itself says. Proposed: "MVMHash's lazy build in `bind_key`
  and deserialize".
