/* worklist-arith.c: the GC worklist's counter arithmetic, without the memory.
 *
 * Mirrors src/gc/worklist.{h,c} (MVM_gc_worklist_presize_for,
 * MVM_gc_worklist_add_slow, the _nocheck and checked add macros, get) with the
 * list replaced by its capacity: every write records the index it would store
 * at and compares it with the number of entries the last (re)allocation made
 * room for. Nothing of that size is allocated.
 *
 * Built twice:
 *   cc -O2 -DOLD worklist-arith.c   counters and presize count as upstream:
 *                                   MVMuint32 items/alloc, MVMint32 count
 *   cc -O2 worklist-arith.c         as on the fix branch: MVMuint64 for all three
 *
 * Scenario per array size E (what VMArray_gc_mark of an object array of E
 * elements does in a full collection, include_gen2 = 1, where every slot is
 * added): a worklist made by MVM_gc_worklist_create (alloc 256) that already
 * holds 100 items; presize_for(E) called with the MVMuint64 elems as the
 * argument; E _nocheck adds; then the collector's loop for 1000 steps: get
 * one item, mark it, which adds 2 entries through the checked add (each
 * element is an object with two references). Prints, per E: the alloc after
 * the presize, the first write at or past the capacity (if any) and where it
 * happened.
 */
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#ifdef OLD
typedef uint32_t count_t;   /* MVMuint32 items, alloc */
typedef int32_t  param_t;   /* MVMint32 items parameter */
#define NAME "upstream (MVMuint32 items/alloc, MVMint32 presize count)"
#else
typedef uint64_t count_t;
typedef uint64_t param_t;
#define NAME "fixed (MVMuint64 items/alloc and presize count)"
#endif

typedef struct { count_t items, alloc; uint64_t capacity; } WL;
static int overflowed; static char where[200];

static void write_at(WL *w, count_t idx, const char *what, uint64_t step) {
    if (!overflowed && (uint64_t)idx >= w->capacity) {
        overflowed = 1;
        snprintf(where, sizeof where, "%s (step %" PRIu64 "): index %" PRIu64 " >= capacity %" PRIu64,
            what, step, (uint64_t)idx, w->capacity);
    }
}
static void my_realloc(WL *w) { w->capacity = (uint64_t)w->alloc; } /* alloc * sizeof(ptr) bytes */
static void add_slow(WL *w, uint64_t step) {
    if (w->items == w->alloc) {
        w->alloc *= 2;
        my_realloc(w);
    }
    write_at(w, w->items++, "checked add (add_slow)", step);
}
static void add_checked(WL *w, uint64_t step) {
    if (w->items == w->alloc) add_slow(w, step);
    else write_at(w, w->items++, "checked add", step);
}
static void presize_for(WL *w, param_t items) {
    if (w->items + items >= w->alloc) {
        w->alloc = w->items + items;
        my_realloc(w);
    }
}

int main(void) {
    uint64_t sizes[] = { 1000000, 2147483000ULL, 2147483548ULL, 2147483648ULL,
                         3221225472ULL, 4294967000ULL, 4294967296ULL + 16, 8589934592ULL };
    unsigned n;
    printf("%s\n", NAME);
    for (n = 0; n < sizeof sizes / sizeof sizes[0]; n++) {
        uint64_t E = sizes[n], i;
        WL w = { 100, 256, 256 };
        overflowed = 0; where[0] = 0;
        presize_for(&w, E);   /* the MVMuint64 elems converted to the parameter type */
        uint64_t after_presize = w.alloc;
        /* E _nocheck adds: list[items++] = slot, in closed form. The indices
         * stored at are items, items+1, ... in count_t arithmetic. */
        {
            uint64_t first = w.items, last_true = (uint64_t)w.items + E - 1;
            uint64_t span = (uint64_t)(count_t)~(count_t)0;   /* largest count_t */
            /* Stored at first + j for j = 0 .. E-1, reduced to count_t. Past
             * the list: some unwrapped index in [capacity, span], or, if the
             * index wraps, some wrapped index (0 .. last_true - span - 1)
             * at or past capacity. */
            uint64_t lo = first > w.capacity ? first : w.capacity;
            uint64_t hi = last_true < span ? last_true : span;
            if (E > 0 && lo <= hi)
                write_at(&w, (count_t)lo, "_nocheck add", lo - first);
            else if (E > 0 && last_true > span && last_true - span - 1 >= w.capacity)
                write_at(&w, (count_t)w.capacity, "_nocheck add (after items wrapped)",
                    span - first + 1 + w.capacity);
            w.items = (count_t)(first + E);
        }
        for (i = 0; i < 1000 && !overflowed; i++) {
            if (w.items) w.items--;             /* MVM_gc_worklist_get */
            add_checked(&w, i); add_checked(&w, i);
        }
        printf("E = %-11" PRIu64 " alloc after presize %-11" PRIu64 " %s%s\n", E, after_presize,
            overflowed ? "WRITE PAST THE LIST: " : "no write past the list (1000 steps)", where);
    }
    return 0;
}
