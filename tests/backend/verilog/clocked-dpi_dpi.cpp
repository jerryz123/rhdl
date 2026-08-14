// Implements the external C symbol linked into the clocked DPI simulation.
#include <cstdint>

extern "C" void rhdl_trace(std::uint8_t value) {
  (void)value;
}

extern "C" std::uint8_t rhdl_step(std::uint8_t value) {
  return static_cast<std::uint8_t>(value + 1);
}
