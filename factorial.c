#include <stdint.h>

#if defined(WIN64) || defined(_WIN64)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT
#endif

EXPORT uint64_t factorial() {
  int i = 10;
  uint64_t result = 1;

  while (i >= 2) {
    result *= i--;
  }

  return result;
}