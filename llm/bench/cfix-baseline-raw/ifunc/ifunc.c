/* Which implementation the dynamic linker bound memcpy and memmove to in this
 * process: the address of an IFUNC symbol, taken through the GOT, is the
 * address of the variant its resolver selected. */
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
int main(void) {
    void *(*volatile mc)(void *, const void *, size_t) = memcpy;
    void *(*volatile mm)(void *, const void *, size_t) = memmove;
    void *mc2 = dlsym(RTLD_DEFAULT, "memcpy"), *mm2 = dlsym(RTLD_DEFAULT, "memmove");
    printf("memcpy  -> %p (dlsym %p)\nmemmove -> %p (dlsym %p)\nsame: %s\n",
           (void *)mc, mc2, (void *)mm, mm2, (void *)mc == (void *)mm ? "yes" : "no");
    return 0;
}
