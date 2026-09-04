// Exercises CHI DPI memory width, masking, zero-fill, and instance isolation.
#include "chi_dpi_memory_dpi.h"

#include <array>
#include <cassert>
#include <cstddef>
#include <cstdint>

namespace {

constexpr std::size_t kWords = 512 / 32;

using PackedData = std::array<svBitVecVal, kWords>;

void set_byte(PackedData& data, std::size_t index, std::uint8_t value) {
  const std::size_t word = index / 4;
  const std::size_t shift = (index % 4) * 8;
  data[word] |= static_cast<svBitVecVal>(value) << shift;
}

std::uint8_t get_byte(const PackedData& data, std::size_t index) {
  const std::size_t word = index / 4;
  const std::size_t shift = (index % 4) * 8;
  return static_cast<std::uint8_t>(data[word] >> shift);
}

}  // namespace

int main() {
  for (const unsigned char beat_bytes : {16, 32, 64}) {
    PackedData written{};
    PackedData read{};
    for (std::size_t lane = 0; lane < beat_bytes; ++lane) {
      set_byte(written, lane, static_cast<std::uint8_t>(lane + beat_bytes));
    }
    const std::uint64_t mask = beat_bytes == 64
        ? ~std::uint64_t{0}
        : (std::uint64_t{1} << beat_bytes) - 1;
    assert(rhodium_chi_memory_access(beat_bytes,
                                     beat_bytes,
                                     1,
                                     0x123,
                                     written.data(),
                                     static_cast<long long>(mask),
                                     read.data()) == 0);
    read.fill(0);
    assert(rhodium_chi_memory_access(beat_bytes,
                                     beat_bytes,
                                     0,
                                     0x120,
                                     written.data(),
                                     0,
                                     read.data()) == 0);
    for (std::size_t lane = 0; lane < beat_bytes; ++lane) {
      assert(get_byte(read, lane) ==
             static_cast<std::uint8_t>(lane + beat_bytes));
    }
  }

  PackedData partial{};
  PackedData read{};
  set_byte(partial, 2, 0xa5);
  set_byte(partial, 7, 0x5a);
  assert(rhodium_chi_memory_access(100,
                                   16,
                                   1,
                                   0x200,
                                   partial.data(),
                                   (std::uint64_t{1} << 2) |
                                       (std::uint64_t{1} << 7),
                                   read.data()) == 0);
  read.fill(0xff);
  assert(rhodium_chi_memory_access(100,
                                   16,
                                   0,
                                   0x20f,
                                   partial.data(),
                                   0,
                                   read.data()) == 0);
  assert(get_byte(read, 2) == 0xa5);
  assert(get_byte(read, 7) == 0x5a);
  assert(get_byte(read, 3) == 0);

  PackedData first_beat{};
  PackedData second_beat{};
  PackedData block_read{};
  set_byte(first_beat, 0, 0x11);
  set_byte(second_beat, 0, 0x22);
  assert(rhodium_chi_memory_access(101,
                                   16,
                                   1,
                                   0x300,
                                   first_beat.data(),
                                   1,
                                   block_read.data()) == 0);
  assert(rhodium_chi_memory_access(101,
                                   16,
                                   1,
                                   0x310,
                                   second_beat.data(),
                                   1,
                                   block_read.data()) == 0);
  assert(rhodium_chi_memory_access(101,
                                   16,
                                   0,
                                   0x300,
                                   first_beat.data(),
                                   0,
                                   block_read.data()) == 0);
  assert(get_byte(block_read, 0) == 0x11);
  assert(rhodium_chi_memory_access(101,
                                   16,
                                   0,
                                   0x310,
                                   second_beat.data(),
                                   0,
                                   block_read.data()) == 0);
  assert(get_byte(block_read, 0) == 0x22);

  PackedData isolated{};
  assert(rhodium_chi_memory_access(102,
                                   16,
                                   0,
                                   0x200,
                                   partial.data(),
                                   0,
                                   isolated.data()) == 0);
  assert(get_byte(isolated, 2) == 0);
  assert(rhodium_chi_memory_access(103,
                                   8,
                                   0,
                                   0,
                                   partial.data(),
                                   0,
                                   isolated.data()) != 0);
}
